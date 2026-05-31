// supabase/functions/analyze-mockexam/index.ts
// 모의고사 스캔 이미지를 Gemini로 분석하는 Supabase Edge Function.
// GEMINI_API_KEY 는 코드에 넣지 말고 Supabase 시크릿으로 저장합니다.
//   supabase secrets set GEMINI_API_KEY=발급받은키

const MODEL = "gemini-2.5-flash"; // 더 강한 추론이 필요하면 "gemini-3.5-flash" 로 변경

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const KEY = Deno.env.get("GEMINI_API_KEY");
    if (!KEY) throw new Error("GEMINI_API_KEY 시크릿이 설정되지 않았습니다.");

    const {
      images = [],
      examName = "",
      subjectHint = "",
      answerKey = "",
      studentName = "",
    } = await req.json();

    if (!Array.isArray(images) || images.length === 0) {
      throw new Error("분석할 이미지가 없습니다.");
    }

    const prompt = `당신은 한국 학교의 베테랑 교사입니다. 첨부된 시험지(모의고사) 스캔을 분석하세요.
학생 이름: ${studentName || "(미상)"}
시험명: ${examName || "(미상)"}
과목 힌트: ${subjectHint || "(없음 - 스스로 판별)"}
정답/채점 정보: ${answerKey ? answerKey : "(없음)"}

규칙:
- 시험지에서 과목을 먼저 판별하세요.
- 정답/채점 정보가 주어졌으면 그 기준으로 정확히 채점하고 grading_mode 를 "정답 기준 채점"으로 하세요.
- 정답 정보가 없으면, 문제를 직접 풀어 학생이 고른 답과 비교해 추정 채점하되 grading_mode 를 "AI 추정 채점(참고용)"으로 하세요. 수학·과학은 직접 풀이의 신뢰도가 높지만 암기·해석형 과목은 불확실할 수 있음을 comment 에 밝히세요.
- 절대 기억에 의존해 임의의 '공식 정답'을 지어내지 마세요. 확신이 없으면 불확실하다고 쓰세요.
- 학생이 약한 단원/유형을 구체적으로 짚고, 앞으로 집중할 부분과 실천 가능한 학습법을 제시하세요.
- 모든 텍스트는 한국어로 작성하세요.

아래 JSON 형식으로만 답하세요(설명 문장이나 마크다운 없이 JSON 만):
{
  "subject": "과목명",
  "exam_name": "시험명(알 수 있으면, 모르면 빈 문자열)",
  "grading_mode": "정답 기준 채점" 또는 "AI 추정 채점(참고용)",
  "score_summary": "예: 추정 18/25 또는 정답률 72% (모르면 빈 문자열)",
  "weak_areas": ["약점 단원/유형 1", "약점 2"],
  "focus": ["앞으로 집중할 부분 1", "2"],
  "study_plan": ["구체적이고 실천 가능한 학습법 1", "2"],
  "comment": "교사용 종합 코멘트 (채점 신뢰도 관련 주의사항 포함)"
}`;

    const parts = [
      ...images.map((im: { mime?: string; data: string }) => ({
        inline_data: { mime_type: im.mime || "image/jpeg", data: im.data },
      })),
      { text: prompt },
    ];

    const gRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: { responseMimeType: "application/json", temperature: 0.2 },
        }),
      },
    );

    if (!gRes.ok) {
      const t = await gRes.text();
      throw new Error(`Gemini 오류 ${gRes.status}: ${t.slice(0, 400)}`);
    }

    const gJson = await gRes.json();
    const text =
      gJson?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text || "").join("") || "";

    let result: unknown;
    try {
      result = JSON.parse(text);
    } catch {
      result = JSON.parse(text.replace(/```json|```/g, "").trim());
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
