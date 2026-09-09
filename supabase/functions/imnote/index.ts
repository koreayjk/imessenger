// Supabase Edge Function: imnote
// IM노트의 서버 작업 두 가지를 처리합니다. (앱의 imClipUrl() / imOcrAttachment() 가 호출)
//   action: "clip" → { url }       링크를 열어 제목·대표이미지·본문을 뽑고, 가능하면 요약까지
//   action: "ocr"  → { imageUrl }  사진 속 글자를 뽑아 검색 가능하게
//
// 주의: 브라우저는 다른 사이트를 직접 가져올 수 없어(CORS) 서버가 대신 가져옵니다.
//       네이버 블로그/카페, 인스타그램, 로그인·유료 기사처럼 막힌 곳은 실패할 수 있고,
//       그때는 앱이 "링크만 저장하고 직접 붙여넣기"로 넘어갑니다.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
const MODELS = ["gemini-3.6-flash", "gemini-flash-latest", "gemini-2.5-flash", "gemini-2.0-flash"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const MAX_HTML = 3_000_000;   // 3MB 넘는 페이지는 앞부분만
const MAX_IMG = 6_000_000;    // 6MB 넘는 사진은 거절
const FETCH_MS = 15_000;

async function fetchWithTimeout(url: string, init: RequestInit = {}, ms = FETCH_MS) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: ac.signal, redirect: "follow" });
  } finally {
    clearTimeout(timer);
  }
}

// ── HTML 유틸 ───────────────────────────────────────────────
function decodeEntities(s: string): string {
  const named: Record<string, string> = {
    amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
    ldquo: "“", rdquo: "”", lsquo: "‘", rsquo: "’",
    hellip: "…", mdash: "—", ndash: "–", middot: "·", bull: "·",
  };
  return s
    .replace(/&#x([0-9a-f]+);/gi, (_m, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_m, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&([a-z]+);/gi, (m, n) => named[String(n).toLowerCase()] ?? m);
}

function metaOf(html: string, ...names: string[]): string {
  for (const name of names) {
    const esc = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const re = new RegExp(
      `<meta[^>]+(?:property|name)\\s*=\\s*["']${esc}["'][^>]*>`, "i");
    const tag = html.match(re)?.[0];
    if (!tag) continue;
    const val = tag.match(/content\s*=\s*["']([^"']*)["']/i)?.[1];
    if (val && val.trim()) return decodeEntities(val.trim());
  }
  return "";
}

function extractText(html: string): string {
  // <head> 는 통째로 제외 (제목·메타는 따로 뽑으므로 본문에 섞이면 중복)
  let h = html.replace(/<head\b[\s\S]*?<\/head>/i, " ");
  // 본문이 아닌 덩어리 제거
  h = h.replace(/<(script|style|noscript|svg|iframe|form|template)\b[\s\S]*?<\/\1>/gi, " ");
  h = h.replace(/<(nav|header|footer|aside)\b[\s\S]*?<\/\1>/gi, " ");
  h = h.replace(/<!--[\s\S]*?-->/g, " ");
  // 줄바꿈이 되는 태그를 개행으로
  h = h.replace(/<\/(p|div|section|article|li|tr|h[1-6]|blockquote)\s*>/gi, "\n");
  h = h.replace(/<br\s*\/?>/gi, "\n");
  h = h.replace(/<li\b[^>]*>/gi, "- ");
  // 남은 태그 제거
  h = h.replace(/<[^>]+>/g, " ");
  h = decodeEntities(h);
  // 공백 정리 (빈 줄 3개 이상 → 2개)
  h = h.replace(/[ \t ]+/g, " ")
       .replace(/ *\n */g, "\n")
       .replace(/\n{3,}/g, "\n\n")
       .trim();
  return h;
}

// ── Gemini ──────────────────────────────────────────────────
async function callGemini(parts: unknown[], maxTokens: number): Promise<string> {
  if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY가 설정되어 있지 않습니다");
  let lastErr = "";
  const models = [...MODELS];
  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    const res = await fetchWithTimeout(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts }],
          generationConfig: { temperature: 0.2, maxOutputTokens: maxTokens },
        }),
      },
      30_000,
    );
    const raw = await res.text();
    if (res.ok) {
      let j: any;
      try { j = JSON.parse(raw); } catch { throw new Error("Gemini 응답을 해석하지 못했습니다"); }
      const ps = j?.candidates?.[0]?.content?.parts ?? [];
      // 사고(thinking) 파트는 걸러내고 실제 텍스트만
      return ps.filter((x: any) => x && x.thought !== true && typeof x.text === "string")
               .map((x: any) => x.text).join("").trim();
    }
    lastErr = `[${res.status}] ${raw.slice(0, 300)}`;
    // "use models/XXX" 안내가 오면 그 모델을 다음 차례로
    const hint = raw.match(/use\s+models\/([A-Za-z0-9._-]+)/)?.[1];
    if (hint && !models.includes(hint)) models.splice(i + 1, 0, hint);
    if (res.status !== 404 && res.status !== 400) break;
  }
  throw new Error("Gemini 오류 " + lastErr);
}

// ── action: clip ────────────────────────────────────────────
async function doClip(url: string) {
  let u: URL;
  try { u = new URL(url); } catch { return json({ ok: false, error: "주소 형식이 올바르지 않습니다" }, 400); }
  if (!/^https?:$/.test(u.protocol)) return json({ ok: false, error: "http/https 주소만 가져올 수 있습니다" }, 400);

  // 유튜브는 페이지를 긁는 대신 공식 oEmbed 사용 (훨씬 정확)
  if (/(^|\.)(youtube\.com|youtu\.be)$/i.test(u.hostname)) {
    try {
      const r = await fetchWithTimeout(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(url)}`);
      if (r.ok) {
        const j = await r.json();
        return json({
          ok: true, url, title: j.title ?? url, site: "YouTube",
          image: j.thumbnail_url ?? "", text: `${j.title ?? ""}\n${j.author_name ?? ""}`.trim(),
        });
      }
    } catch { /* 아래 일반 처리로 */ }
  }

  let res: Response;
  try {
    res = await fetchWithTimeout(url, {
      headers: {
        "User-Agent": UA,
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
      },
    });
  } catch (e) {
    const msg = String((e as Error)?.name === "AbortError" ? "시간 초과" : (e as Error)?.message || e);
    return json({ ok: false, error: `사이트에 연결하지 못했습니다 (${msg})` }, 200);
  }

  if (!res.ok) return json({ ok: false, error: `사이트가 ${res.status} 로 거절했습니다` }, 200);

  const ctype = res.headers.get("content-type") ?? "";
  if (!/text\/html|application\/xhtml/i.test(ctype)) {
    return json({ ok: false, error: `웹페이지가 아닙니다 (${ctype.split(";")[0] || "형식 불명"})` }, 200);
  }

  let html = await res.text();
  if (html.length > MAX_HTML) html = html.slice(0, MAX_HTML);

  const title = metaOf(html, "og:title", "twitter:title")
    || decodeEntities((html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "").trim())
    || url;
  const site = metaOf(html, "og:site_name") || u.hostname.replace(/^www\./, "");
  const image = metaOf(html, "og:image", "twitter:image");
  const desc = metaOf(html, "og:description", "description");

  let text = extractText(html);
  if (text.length > 40_000) text = text.slice(0, 40_000) + "\n…";

  // 본문이 너무 짧으면 JS로만 그리는 사이트일 가능성이 큼 → 앱이 '직접 붙여넣기'로 안내
  if (text.length < 200) {
    if (desc) {
      return json({ ok: true, url, title, site, image, text: desc, thin: true });
    }
    return json({ ok: false, error: "이 사이트는 내용을 읽을 수 없게 되어 있습니다" }, 200);
  }

  // 요약 (실패해도 클리핑 자체는 성공)
  let summary = "";
  if (GEMINI_API_KEY && text.length > 600) {
    try {
      summary = await callGemini([{
        text: "다음 글을 한국어로 3~5줄로 요약해 줘. 군더더기 없이 핵심만, 불릿 없이 문장으로.\n\n"
          + text.slice(0, 12_000),
      }], 800);
    } catch { /* 요약은 있으면 좋은 것 */ }
  }

  return json({ ok: true, url, title, site, image, text, summary });
}

// ── action: ocr ─────────────────────────────────────────────
function toBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let bin = "";
  const CHUNK = 0x8000;   // 한 번에 넘기면 스택이 넘칩니다
  for (let i = 0; i < bytes.length; i += CHUNK) {
    bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(bin);
}

async function doOcr(imageUrl: string) {
  let res: Response;
  try {
    res = await fetchWithTimeout(imageUrl, { headers: { "User-Agent": UA } });
  } catch {
    return json({ ok: false, error: "이미지를 불러오지 못했습니다" }, 200);
  }
  if (!res.ok) return json({ ok: false, error: `이미지를 불러오지 못했습니다 (${res.status})` }, 200);

  const ctype = (res.headers.get("content-type") ?? "").split(";")[0] || "image/jpeg";
  if (!ctype.startsWith("image/")) return json({ ok: false, error: "이미지 파일이 아닙니다" }, 200);

  const buf = await res.arrayBuffer();
  if (buf.byteLength > MAX_IMG) return json({ ok: false, error: "사진이 너무 큽니다 (6MB 이하)" }, 200);

  const text = await callGemini([
    { text: "이 이미지에 보이는 글자를 그대로 옮겨 적어 줘. 설명이나 해석은 붙이지 말고 보이는 텍스트만. 글자가 없으면 빈 문자열로." },
    { inline_data: { mime_type: ctype, data: toBase64(buf) } },
  ], 2048);

  return json({ ok: true, text });
}

// ── 진입점 ──────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "POST 만 지원합니다" }, 405);

  let body: any;
  try { body = await req.json(); } catch { return json({ ok: false, error: "요청 형식이 올바르지 않습니다" }, 400); }

  try {
    const action = String(body?.action ?? "");
    if (action === "clip") {
      if (!body?.url) return json({ ok: false, error: "url 이 필요합니다" }, 400);
      return await doClip(String(body.url));
    }
    if (action === "ocr") {
      if (!body?.imageUrl) return json({ ok: false, error: "imageUrl 이 필요합니다" }, 400);
      return await doOcr(String(body.imageUrl));
    }
    return json({ ok: false, error: `알 수 없는 action: ${action}` }, 400);
  } catch (e) {
    return json({ ok: false, error: (e as Error)?.message ?? String(e) }, 200);
  }
});
