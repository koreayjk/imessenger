// Supabase Edge Function: gcal-sync
// TCS 일정 ↔ 구글 캘린더 동기화.
//
// 전용 서비스 계정 하나로 '공유받은 캘린더'를 읽고 씁니다.
// 개별 사용자의 구글 로그인(OAuth)은 필요 없습니다.
//
// 준비 (한 번만)
//   1) Google Cloud Console → 서비스 계정 만들기 → JSON 키 내려받기
//   2) Google Calendar API 사용 설정
//   3) 구글 캘린더 → 해당 캘린더 설정 → '특정 사용자와 공유'에
//      서비스 계정 이메일(...iam.gserviceaccount.com)을 추가하고
//      권한을 '변경 및 공유 관리'로 줍니다
//   4) Supabase → Edge Functions → Secrets 에 아래를 등록
//        GOOGLE_SERVICE_ACCOUNT : 내려받은 JSON 전체를 그대로 붙여넣기
//   5) 공동체 설정에서 캘린더 ID 를 입력 (캘린더 설정 → 캘린더 통합 → 캘린더 ID)
//
// 어느 캘린더를 쓸지는 호출자의 토큰으로 서버가 판단합니다.
// (클라이언트가 보낸 공동체 ID 를 그대로 믿으면 남의 캘린더를 만질 수 있습니다)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SA_RAW = Deno.env.get("GOOGLE_SERVICE_ACCOUNT") ?? "";
const SCOPE = "https://www.googleapis.com/auth/calendar";
const CAL = "https://www.googleapis.com/calendar/v3";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

// ── 서비스 계정 토큰 ───────────────────────────────────────────────
const b64url = (buf: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(buf as ArrayBuffer)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const enc = (s: string) => new TextEncoder().encode(s);

function pemToDer(pem: string): ArrayBuffer {
  const body = String(pem)
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

let cachedToken: { token: string; exp: number } | null = null;

// 시크릿에서 서비스 계정 이메일만 꺼낸다 (화면에 보여 주려고)
function serviceAccountEmail(): string {
  try { return JSON.parse(SA_RAW)?.client_email || ""; } catch { return ""; }
}

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.exp > Date.now() / 1000 + 60) return cachedToken.token;
  if (!SA_RAW) throw new Error("GOOGLE_SERVICE_ACCOUNT 시크릿이 없습니다.");

  let sa: any;
  try { sa = JSON.parse(SA_RAW); }
  catch { throw new Error("GOOGLE_SERVICE_ACCOUNT 가 올바른 JSON 이 아닙니다."); }
  if (!sa.client_email || !sa.private_key) throw new Error("서비스 계정 JSON 에 client_email 또는 private_key 가 없습니다.");
  // 시크릿에 붙여넣을 때 줄바꿈이 \n 글자로 들어가는 경우가 많다
  const pem = String(sa.private_key).replace(/\\n/g, "\n");

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = { iss: sa.client_email, scope: SCOPE, aud: "https://oauth2.googleapis.com/token", exp: now + 3600, iat: now };
  const unsigned = `${b64url(enc(JSON.stringify(header)))}.${b64url(enc(JSON.stringify(claim)))}`;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc(unsigned));
  const jwt = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.access_token) {
    throw new Error(`구글 토큰을 받지 못했습니다: ${body.error_description || body.error || res.status}`);
  }
  cachedToken = { token: body.access_token, exp: now + (body.expires_in || 3600) };
  return cachedToken.token;
}

async function gcal(token: string, path: string, init: RequestInit = {}) {
  const res = await fetch(`${CAL}${path}`, {
    ...init,
    headers: { ...(init.headers || {}), Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  });
  const text = await res.text();
  let body: any = null;
  try { body = text ? JSON.parse(text) : null; } catch { /* 본문 없음 */ }
  if (!res.ok) {
    const msg = body?.error?.message || text || String(res.status);
    const err: any = new Error(msg);
    err.status = res.status;
    throw err;
  }
  return body;
}

// ── TCS 일정 ↔ 구글 일정 옮겨 담기 ─────────────────────────────────
// 시각이 없으면 '종일 일정'(date), 있으면 시각 일정(dateTime).
// 구글의 종일 일정은 끝 날짜가 '다음 날'이다 (9/23 하루 → end 9/24).
const addDay = (ymd: string) => {
  const [y, m, d] = ymd.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + 1));
  return dt.toISOString().slice(0, 10);
};
const subDay = (ymd: string) => {
  const [y, m, d] = ymd.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d - 1));
  return dt.toISOString().slice(0, 10);
};

function toGoogle(ev: any, tz: string) {
  const startDate = ev.start_date;
  const endDate = ev.end_date || ev.start_date;
  const body: any = {
    summary: ev.title || "(제목 없음)",
    description: ev.description || undefined,
  };
  if (ev.start_time) {
    body.start = { dateTime: `${startDate}T${(ev.start_time + ":00").slice(0, 8)}`, timeZone: tz };
    const endT = ev.end_time || ev.start_time;
    body.end = { dateTime: `${endDate}T${(endT + ":00").slice(0, 8)}`, timeZone: tz };
  } else {
    body.start = { date: startDate };
    body.end = { date: addDay(endDate) };   // 구글은 끝이 '다음 날'
  }
  return body;
}

function fromGoogle(g: any) {
  const sd = g.start?.date || (g.start?.dateTime || "").slice(0, 10);
  const ed = g.end?.date || (g.end?.dateTime || "").slice(0, 10);
  const allDay = !!g.start?.date;
  // 종일 일정은 구글에서 끝이 '다음 날'이므로 하루 되돌린다.
  // 되돌린 값이 시작일과 같으면(=하루짜리) TCS 규칙대로 비운다.
  let endOut: string | null = null;
  if (ed) {
    const back = allDay ? subDay(ed) : ed;
    endOut = back === sd ? null : back;
  }
  return {
    title: g.summary || "(제목 없음)",
    description: g.description || null,
    start_date: sd,
    end_date: endOut,
    start_time: allDay ? null : (g.start?.dateTime || "").slice(11, 16) || null,
    end_time: allDay ? null : (g.end?.dateTime || "").slice(11, 16) || null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST 로 호출해 주세요." }, 405);
  if (!SUPABASE_URL || !SERVICE_KEY) return json({ error: "서버 설정이 빠져 있습니다." }, 500);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "로그인이 필요합니다." }, 401);

  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: u, error: uErr } = await asUser.auth.getUser();
  const uid = u?.user?.id;
  const userEmail = u?.user?.email || "";
  if (uErr || !uid) return json({ error: "로그인 정보를 확인할 수 없습니다." }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  // 공동체는 호출자의 소속으로 정한다 (총관리자만 지정 가능)
  const { data: me } = await admin.from("members")
    .select("community_id, community_role, role").eq("id", uid).maybeSingle();
  if (!me) return json({ error: "구성원 정보를 찾을 수 없습니다." }, 403);
  const isSuper = me.community_role === "super_admin" || me.role === "총관리자";

  let body: any = {};
  try { body = await req.json(); } catch { /* 본문 없음 */ }
  const cid = (isSuper && body?.communityId) ? String(body.communityId) : me.community_id;
  if (!cid) return json({ error: "소속 공동체를 찾을 수 없습니다." }, 400);

  const { data: comm } = await admin.from("communities")
    .select("id, name, google_calendar_id").eq("id", cid).maybeSingle();
  const calId = (comm?.google_calendar_id || "").trim();
  const tz = String(body?.timeZone || "Asia/Seoul");
  const action = String(body?.action || "sync");

  // 설정 화면에 보여 줄 정보 — 토큰 없이도 답한다
  if (action === "info") {
    return json({
      ok: true,
      serviceAccount: serviceAccountEmail(),
      hasSecret: !!SA_RAW,
      calendarId: calId,
      communityName: comm?.name || "",
      myEmail: userEmail,
    });
  }

  if (!calId && action !== "create") {
    return json({ needsCalendar: true, communityName: comm?.name || "",
      message: "연동할 구글 캘린더가 없습니다. '캘린더 만들기' 를 누르거나, 쓰던 캘린더의 ID 를 넣어주세요." });
  }

  let token: string;
  try { token = await getAccessToken(); }
  catch (e) { return json({ error: String((e as Error).message) }, 500); }

  // ── 누가 이 캘린더를 볼 수 있는지 ──────────────────────────────
  //   동기화는 서비스 계정이 하므로, 여기 없는 관리자도 TCS 안에서는
  //   일정을 다 본다. 이 목록은 '자기 구글 캘린더 앱에서도 보는 사람' 이다.
  if (action === "acl") {
    if (!calId) return json({ ok: true, people: [] });
    try {
      const list = await gcal(token, `/calendars/${encodeURIComponent(calId)}/acl`);
      const people = (list.items ?? [])
        .filter((a: any) => a.scope?.type === "user" && a.scope?.value)
        // 사람이 아닌 항목은 뺀다.
        //  · 서비스 계정 — 지우면 동기화가 통째로 멈춘다
        //  · 캘린더 자기 자신 (…@group.calendar.google.com) — 구글이 자동으로 넣는다
        .filter((a: any) => {
          const v = String(a.scope.value).toLowerCase();
          return !v.endsWith(".iam.gserviceaccount.com")
              && !v.endsWith("@group.calendar.google.com")
              && v !== String(calId).toLowerCase();
        })
        .map((a: any) => ({ id: a.id, email: a.scope.value, role: a.role }));
      // 아직 권한이 없는 우리 공동체 관리자들을 추천해 준다
      const { data: admins } = await admin.from("members")
        .select("name, email, community_role, role")
        .eq("community_id", cid).limit(200);
      const have = new Set(people.map((p: any) => String(p.email).toLowerCase()));
      const suggest = (admins ?? [])
        .filter((m: any) =>
          ["super_admin", "community_admin", "admin_officer"].includes(m.community_role) ||
          ["총관리자", "관리자", "행정담당자"].includes(m.role))
        .filter((m: any) => m.email && !have.has(String(m.email).toLowerCase()))
        .map((m: any) => ({ name: m.name, email: m.email }));
      return json({ ok: true, people, suggest });
    } catch (e: any) {
      return json({ error: `권한 목록을 읽지 못했습니다: ${e.message}` }, 400);
    }
  }

  // 권한 주기 / 거두기
  if (action === "share" || action === "unshare") {
    if (!calId) return json({ error: "연결된 캘린더가 없습니다." }, 400);
    try {
      if (action === "unshare") {
        const ruleId = String(body?.ruleId || "");
        if (!ruleId) return json({ error: "지울 대상이 없습니다." }, 400);
        await gcal(token, `/calendars/${encodeURIComponent(calId)}/acl/${encodeURIComponent(ruleId)}`,
          { method: "DELETE" });
        return json({ ok: true, removed: ruleId });
      }
      const emails: string[] = (Array.isArray(body?.emails) ? body.emails : [body?.email])
        .map((x: any) => String(x || "").trim()).filter(Boolean);
      if (!emails.length) return json({ error: "이메일을 넣어주세요." }, 400);
      const role = body?.role === "reader" ? "reader" : "writer";
      const done: string[] = [], failed: string[] = [];
      for (const email of emails) {
        try {
          await gcal(token, `/calendars/${encodeURIComponent(calId)}/acl?sendNotifications=true`, {
            method: "POST",
            body: JSON.stringify({ role, scope: { type: "user", value: email } }),
          });
          done.push(email);
        } catch (_) { failed.push(email); }
      }
      return json({ ok: true, shared: done, failed });
    } catch (e: any) {
      return json({ error: e.message }, 400);
    }
  }

  // ── 캘린더를 대신 만들어 준다 ──────────────────────────────────
  //   공동체마다 구글 콘솔을 만지게 하면 아무도 안 쓴다.
  //   서비스 계정이 캘린더를 만들고, 요청한 관리자에게 권한을 넘겨준다.
  if (action === "create") {
    if (calId && !body?.force) {
      return json({ error: "이미 연결된 캘린더가 있습니다. 새로 만들려면 먼저 캘린더 ID 를 비워주세요." }, 400);
    }
    try {
      const made = await gcal(token, "/calendars", {
        method: "POST",
        body: JSON.stringify({
          summary: `${comm?.name || "TCS"} 일정`,
          description: "TCS 에서 자동으로 만든 공동체 일정 캘린더입니다.",
          timeZone: tz,
        }),
      });
      const newId = made.id;

      // 요청한 관리자가 자기 구글 캘린더에서 볼 수 있게 권한을 준다
      const shared: string[] = [];
      const grant = async (email: string, role: string) => {
        if (!email) return;
        try {
          await gcal(token, `/calendars/${encodeURIComponent(newId)}/acl?sendNotifications=true`, {
            method: "POST",
            body: JSON.stringify({ role, scope: { type: "user", value: email } }),
          });
          shared.push(email);
        } catch (_) { /* 한 명 실패해도 계속 */ }
      };
      await grant(userEmail, "owner");
      for (const extra of (Array.isArray(body?.shareWith) ? body.shareWith : [])) {
        await grant(String(extra), "writer");
      }

      await admin.from("communities").update({ google_calendar_id: newId }).eq("id", cid);
      // 권한을 아무에게도 못 준 경우 — 캘린더는 만들어졌지만 사람 눈에는 안 보인다.
      // 그냥 성공이라고 하면 "만들었다는데 안 보인다" 가 된다.
      const warn = shared.length ? "" :
        (userEmail
          ? "캘린더는 만들어졌지만 권한을 넘기지 못했습니다. 아래 주소를 직접 공유해 주세요."
          : "로그인 계정에 이메일이 없어 권한을 넘기지 못했습니다. 아래 캘린더 ID 를 쓰시거나, 이메일이 있는 계정으로 다시 시도해 주세요.");
      return json({
        ok: true, created: true, calendarId: newId,
        calendarName: made.summary, shared, warn,
        serviceAccount: serviceAccountEmail(),
        link: `https://calendar.google.com/calendar/u/0/r?cid=${encodeURIComponent(newId)}`,
      });
    } catch (e: any) {
      return json({ error: `캘린더를 만들지 못했습니다: ${e.message}` }, 400);
    }
  }

  // 연결만 확인
  if (action === "check") {
    try {
      const cal = await gcal(token, `/calendars/${encodeURIComponent(calId)}`);
      return json({ ok: true, calendarId: calId, calendarName: cal?.summary || "", communityName: comm?.name || "" });
    } catch (e: any) {
      const hint = e.status === 404
        ? "캘린더를 찾을 수 없습니다. 캘린더 ID 가 맞는지, 서비스 계정에 캘린더를 공유했는지 확인해 주세요."
        : e.status === 403
        ? "권한이 없습니다. 캘린더 공유 권한을 '변경 및 공유 관리'로 올려 주세요."
        : String(e.message);
      return json({ error: hint }, 400);
    }
  }

  const report: Record<string, number> = { pushed: 0, updated: 0, pulled: 0, skipped: 0 };
  const problems: string[] = [];

  // ── 1. TCS → 구글 ────────────────────────────────────────────────
  if (action === "sync" || action === "push") {
    const { data: rows } = await admin.from("events").select("*")
      .eq("community_id", cid).order("start_date", { ascending: false }).limit(1000);
    for (const ev of rows ?? []) {
      // 구글에서 가져온 것은 다시 올리지 않는다 (되돌아오며 무한히 늘어난다)
      if (ev.gcal_origin === "google") { report.skipped++; continue; }
      try {
        const payload = toGoogle(ev, tz);
        if (ev.google_event_id) {
          await gcal(token, `/calendars/${encodeURIComponent(calId)}/events/${encodeURIComponent(ev.google_event_id)}`,
            { method: "PATCH", body: JSON.stringify(payload) });
          report.updated++;
        } else {
          const made = await gcal(token, `/calendars/${encodeURIComponent(calId)}/events`,
            { method: "POST", body: JSON.stringify(payload) });
          await admin.from("events").update({
            google_event_id: made.id, gcal_origin: "tcs", gcal_synced_at: new Date().toISOString(),
          }).eq("id", ev.id);
          report.pushed++;
        }
      } catch (e: any) {
        // 구글에서 지워진 일정이면 짝을 풀어 다음번에 새로 만든다
        if (e.status === 404 && ev.google_event_id) {
          await admin.from("events").update({ google_event_id: null }).eq("id", ev.id);
        }
        if (problems.length < 5) problems.push(`${ev.title}: ${e.message}`);
      }
    }
  }

  // ── 2. 구글 → TCS ────────────────────────────────────────────────
  if (action === "sync" || action === "pull") {
    // 지난 6개월 ~ 앞으로 2년
    const from = new Date(); from.setMonth(from.getMonth() - 6);
    const to = new Date(); to.setFullYear(to.getFullYear() + 2);
    try {
      let pageToken: string | undefined;
      do {
        const q = new URLSearchParams({
          singleEvents: "true", maxResults: "250", orderBy: "startTime",
          timeMin: from.toISOString(), timeMax: to.toISOString(),
        });
        if (pageToken) q.set("pageToken", pageToken);
        const page = await gcal(token, `/calendars/${encodeURIComponent(calId)}/events?${q}`);
        for (const g of page.items ?? []) {
          if (g.status === "cancelled") continue;
          const { data: exist } = await admin.from("events").select("id, gcal_origin")
            .eq("community_id", cid).eq("google_event_id", g.id).maybeSingle();
          const mapped = fromGoogle(g);
          if (!mapped.start_date) continue;
          if (exist) {
            // TCS 가 원본인 일정은 구글 쪽 내용으로 덮지 않는다 (TCS 가 주인)
            if (exist.gcal_origin === "tcs") { report.skipped++; continue; }
            await admin.from("events").update({ ...mapped, gcal_synced_at: new Date().toISOString() })
              .eq("id", exist.id);
          } else {
            await admin.from("events").insert({
              ...mapped, community_id: cid, color: "#4285F4", category: null,
              created_by: uid, created_by_name: "구글 캘린더",
              google_event_id: g.id, gcal_origin: "google", gcal_synced_at: new Date().toISOString(),
            });
            report.pulled++;
          }
        }
        pageToken = page.nextPageToken;
      } while (pageToken);
    } catch (e: any) {
      if (problems.length < 5) problems.push(`가져오기: ${e.message}`);
    }
  }

  return json({ ok: true, calendarId: calId, report, problems });
});
