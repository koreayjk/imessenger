// Supabase Edge Function: analyze-reading
// 학생이 제출한 '최종 독후감'을 분석해 AI 작성 가능성 + 의심 정황 + 학생에게 물어볼
// 후속 질문을 만들어 돌려줍니다. 앱(index.html)의 analyzeReadingReport() 가 호출.
// 응답: { likelihood:"low|medium|high", score:0-100, summary, signals[], excerpts[], questions[] }
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();

// 구글이 모델을 수시로 폐기하므로 최신 → 구버전 순으로 시도한다.
// 404 응답에 "use models/XXX" 안내가 오면 그 모델을 자동으로 먼저 시도한다(자가 복구).
const MODELS = [
  "gemini-3.6-flash",
  "gemini-flash-latest",
  "gemini-2.5-flash",
  "gemini-2.0-flash",
];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function extractJson(text: string): any {
  if (!text) return null;
  let t = text.replace(/```json/gi, "```").trim();
  const fence = t.match(/```([\s\S]*?)```/);
  if (fence) t = fence[1].trim();
  const s = t.indexOf("{"), e = t.lastIndexOf("}");
  if (s === -1 || e === -1) return null;
  try { return JSON.parse(t.slice(s, e + 1)); } catch { return null; }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!GEMINI_API_KEY) {
      return json({
        error: "GEMINI_API_KEY 가 이 Edge Function 에 설정되어 있지 않습니다. " +
               "Supabase 대시보드 → Edge Functions → analyze-reading → Secrets 에서 " +
               "이름을 정확히 GEMINI_API_KEY 로 추가한 뒤 다시 시도하세요.",
      }, 400);
    }

    const b = await req.json().catch(() => ({}));
    const report = (b.report || "").toString().trim();
    const bookTitle = (b.bookTitle || "").toString();
    const noteCount = Number(b.noteCount || 0);
    const lang = (b.lang === "en") ? "en" : "ko";

    if (!report || report.length < 20) {
      return json({
        likelihood: "unknown", score: 0,
        summary: lang === "en" ? "The report is too short to analyze." : "분석하기에 글이 너무 짧습니다.",
        signals: [], excerpts: [], questions: [],
      });
    }

    const outLang = lang === "en" ? "English" : "Korean (한국어)";
    const prompt =
`You are an experienced teacher helping to review a student's book report for possible AI generation.
Analyze the FINAL BOOK REPORT below and judge how likely it was written by an AI tool (e.g. ChatGPT) rather than the student.

Consider signals such as: unnaturally uniform and polished register, elevated/abstract vocabulary used consistently, formulaic triads and balanced clauses, lack of personal/idiosyncratic detail, absence of the specific "voice" or small errors a student would have, generic claims not tied to concrete scenes, and mismatch with the number of daily notes the student wrote (this student wrote ${noteCount} daily reading notes for this book — very few notes but a very polished long report is a mild signal).

Be fair and calibrated. AI-detection is uncertain; do NOT accuse. A fluent student can also write well. Note false positives are possible.

Return ONLY a JSON object (no markdown, no prose) with these keys, all written in ${outLang}:
{
  "likelihood": "low" | "medium" | "high",
  "score": <integer 0-100, estimated probability it is AI-written>,
  "summary": "<1-2 sentence balanced overall judgment>",
  "signals": ["<specific observed reason>", "..."],
  "excerpts": ["<a short quoted phrase from the report that looks AI-like>", "..."],
  "questions": ["<a specific follow-up question the teacher can ask the student to verify understanding, referencing the book's actual content>", "..."]
}
Give 2-4 items for signals, up to 3 for excerpts, and 3-5 for questions. The questions must be answerable only by someone who genuinely read and thought about the book.

BOOK TITLE: ${bookTitle}
DAILY NOTES WRITTEN: ${noteCount}

FINAL BOOK REPORT:
"""
${report.slice(0, 8000)}
"""`;

    const body = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.2, maxOutputTokens: 900, responseMimeType: "application/json" },
    });

    // 모델을 순서대로 시도. 404면 다음 모델로 넘어가고,
    // 구글이 "use models/XXX" 로 대체 모델을 알려주면 그것을 최우선으로 시도한다.
    let data: any = null;
    let usedModel = "";
    const tried: string[] = [];
    const queue = [...MODELS];
    const seen = new Set<string>();
    let lastErr = "";

    while (queue.length && tried.length < 8) {
      const model = queue.shift()!;
      if (!model || seen.has(model)) continue;
      seen.add(model);

      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`,
        { method: "POST", headers: { "Content-Type": "application/json" }, body },
      );
      if (res.ok) { data = await res.json(); usedModel = model; break; }

      const errText = await res.text();
      lastErr = errText;
      tried.push(`${model}→${res.status}`);

      // 키 자체가 잘못된 경우는 다른 모델을 시도해도 소용없으니 바로 안내
      if (res.status === 401 || res.status === 403) {
        return json({
          error: `Gemini API key가 거부됐습니다 (${res.status}). Google AI Studio에서 키가 유효한지, ` +
                 `Generative Language API 사용이 허용되어 있는지 확인하세요. 상세: ${errText.slice(0, 300)}`,
        }, 400);
      }
      if (res.status === 429) {
        return json({ error: `Gemini 사용량 한도(429)에 걸렸습니다. 잠시 후 다시 시도하세요. 상세: ${errText.slice(0, 200)}` }, 400);
      }
      // 폐기 안내에서 대체 모델명을 뽑아 최우선으로 시도 (모델이 또 바뀌어도 자동 대응)
      const hint = errText.match(/use\s+models\/([A-Za-z0-9._-]+)/);
      if (hint && hint[1] && !seen.has(hint[1])) queue.unshift(hint[1]);
    }

    if (!data) {
      return json({
        error: `사용 가능한 Gemini 모델을 찾지 못했습니다. 시도: ${tried.join(", ")}. 상세: ${lastErr.slice(0, 300)}`,
      }, 400);
    }

    const text =
      (data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") ?? "").trim();
    const parsed = extractJson(text) || {};

    if (!text) {
      const reason = data?.promptFeedback?.blockReason || data?.candidates?.[0]?.finishReason || "";
      return json({ error: `Gemini가 빈 응답을 돌려줬습니다${reason ? ` (${reason})` : ""}. 잠시 후 다시 시도해 주세요.` }, 400);
    }

    return json({
      likelihood: ["low", "medium", "high"].includes((parsed.likelihood || "").toLowerCase())
        ? parsed.likelihood.toLowerCase() : "unknown",
      score: typeof parsed.score === "number" ? parsed.score : 0,
      summary: (parsed.summary || "").toString(),
      signals: Array.isArray(parsed.signals) ? parsed.signals.slice(0, 6) : [],
      excerpts: Array.isArray(parsed.excerpts) ? parsed.excerpts.slice(0, 3) : [],
      questions: Array.isArray(parsed.questions) ? parsed.questions.slice(0, 6) : [],
    });
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 400);
  }
});
