// Supabase Edge Function: analyze-mockexam
// 학생 시험지(스캔/사진)를 Gemini로 분석해 과목·약점·집중학습·학습법을 반환합니다.
// 앱(index.html)의 runMockAnalysis() 가 호출하며, 응답은 { result: {...} } 형식.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
// 더 똑똑한 분석이 필요하면 "gemini-2.5-flash" 등으로 교체 가능
const MODEL = "gemini-2.0-flash";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// data URL(예: "data:image/jpeg;base64,....") → Gemini inline_data 형식으로
function toInline(b64: string) {
  const m = /^data:(.*?);base64,(.*)$/s.exec(b64 || "");
  if (m) return { mime_type: m[1] || "image/jpeg", data: m[2] };
  return { mime_type: "image/jpeg", data: b64 };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY 가 설정되지 않았습니다");

    const body = await req.json().catch(() => ({}));
    const examImages: string[] = body.examImages || body.images || [];
    const answerImages: string[] = body.answerImages || [];
    const examName = (body.examName || "").toString();
    const subjectHint = (body.subjectHint || "").toString();
    const answerKey = (body.answerKey || "").toString();
    const studentName = (body.studentName || "").toString();

    if (!examImages.length) throw new Error("시험지 이미지가 없습니다");

    const prompt =
`너는 한국 학교 교사를 돕는 채점·학습 분석 도우미야.
아래 학생 시험지(스캔/사진)를 보고 분석해줘.
${examName ? `시험명: ${examName}\n` : ""}${subjectHint ? `과목 힌트: ${subjectHint}\n` : ""}${studentName ? `학생: ${studentName}\n` : ""}${answerKey ? `정답(참고): ${answerKey}\n` : ""}
지침:
- 정답지/점수표가 함께 있으면 그걸로 정확히 채점하고, 없으면 직접 풀어 추정 채점해(이 경우 score_summary에 "추정·참고용"이라고 표시).
- 수학·과학은 추정도 비교적 정확하지만, 국어·암기형은 불확실할 수 있어.
- 모든 결과는 한국어로, 학생에게 도움이 되도록 구체적으로.`;

    const parts: any[] = [{ text: prompt }];
    for (const img of examImages) parts.push({ inline_data: toInline(img) });
    if (answerImages.length) {
      parts.push({ text: "다음은 정답지/점수표입니다(채점 기준으로 사용):" });
      for (const img of answerImages) parts.push({ inline_data: toInline(img) });
    }

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              properties: {
                subject: { type: "STRING" },
                score_summary: { type: "STRING" },
                weak_areas: { type: "ARRAY", items: { type: "STRING" } },
                focus: { type: "ARRAY", items: { type: "STRING" } },
                study_plan: { type: "ARRAY", items: { type: "STRING" } },
              },
              required: ["subject", "weak_areas", "focus", "study_plan"],
            },
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      const t = await geminiRes.text();
      throw new Error(`Gemini 오류 ${geminiRes.status}: ${t.slice(0, 400)}`);
    }

    const data = await geminiRes.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") ?? "";

    let result: any = null;
    try {
      result = JSON.parse(text);
    } catch {
      const m = text.match(/\{[\s\S]*\}/);
      result = m ? JSON.parse(m[0]) : null;
    }
    if (!result || (!result.subject && !result.weak_areas)) {
      throw new Error("분석 결과를 해석하지 못했습니다 (스캔 화질 확인)");
    }

    return new Response(JSON.stringify({ result }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as Error)?.message || e) }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
