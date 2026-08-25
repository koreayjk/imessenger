// Supabase Edge Function: analyze-reading
// 학생이 제출한 '최종 독후감'을 분석해 AI 작성 가능성 + 의심 정황 + 학생에게 물어볼
// 후속 질문을 만들어 돌려줍니다. 앱(index.html)의 analyzeReadingReport() 가 호출.
// 응답: { likelihood:"low|medium|high", score:0-100, summary, signals[], excerpts[], questions[] }
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODEL = "gemini-2.0-flash";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function extractJson(text: string): any {
  if (!text) return null;
  // ```json ... ``` 코드펜스 제거
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
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY 가 설정되지 않았습니다");

    const b = await req.json().catch(() => ({}));
    const report = (b.report || "").toString().trim();
    const bookTitle = (b.bookTitle || "").toString();
    const noteCount = Number(b.noteCount || 0);
    const lang = (b.lang === "en") ? "en" : "ko";

    if (!report || report.length < 20) {
      return new Response(JSON.stringify({
        likelihood: "unknown", score: 0,
        summary: lang === "en" ? "The report is too short to analyze." : "분석하기에 글이 너무 짧습니다.",
        signals: [], excerpts: [], questions: [],
      }), { headers: { ...cors, "Content-Type": "application/json" } });
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

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 900, responseMimeType: "application/json" },
        }),
      },
    );

    if (!res.ok) {
      const tt = await res.text();
      throw new Error(`Gemini 오류 ${res.status}: ${tt.slice(0, 400)}`);
    }

    const data = await res.json();
    const text =
      (data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") ?? "").trim();
    const parsed = extractJson(text) || {};

    const out = {
      likelihood: ["low", "medium", "high"].includes((parsed.likelihood || "").toLowerCase())
        ? parsed.likelihood.toLowerCase() : "unknown",
      score: typeof parsed.score === "number" ? parsed.score : 0,
      summary: (parsed.summary || "").toString(),
      signals: Array.isArray(parsed.signals) ? parsed.signals.slice(0, 6) : [],
      excerpts: Array.isArray(parsed.excerpts) ? parsed.excerpts.slice(0, 3) : [],
      questions: Array.isArray(parsed.questions) ? parsed.questions.slice(0, 6) : [],
    };

    return new Response(JSON.stringify(out), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as Error)?.message || e) }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
