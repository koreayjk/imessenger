// Supabase Edge Function: draft-assessment
// 학생의 관찰기록·출결·상담·독서·활동을 모아 생기부 "행동특성 및 종합의견" 초안을 작성합니다.
// 앱(index.html)의 generateAssessmentDraft() 가 호출하며, 응답은 { draft: "..." } 형식.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const MODEL = "gemini-2.0-flash";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function line(o: any): string {
  const parts = [o.date, o.category, o.title, o.content || o.report || o.body]
    .map((x) => (x ?? "").toString().trim()).filter(Boolean);
  return "- " + parts.join(" | ");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY 가 설정되지 않았습니다");

    const b = await req.json().catch(() => ({}));
    const name = (b.studentName || "이 학생").toString();
    const grade = (b.grade || "").toString();
    const obs: any[] = b.observations || [];
    const cons: any[] = b.counseling || [];
    const att = b.attendance || {};
    const reading: any[] = b.reading || [];
    const writings: any[] = b.writings || [];

    const attLine =
      `출석 관련(${b.attendanceMonth || ""}): 출석 ${att.present || 0}, 지각 ${att.late || 0}, 조퇴 ${att.early || 0}, 결석 ${att.absent || 0}, 병결 ${att.sick || 0}, 인정 ${att.excused || 0}`;

    const sec = (title: string, arr: any[]) =>
      arr.length ? `\n[${title}]\n${arr.map(line).join("\n")}` : "";

    const prompt =
`너는 한국 학교 담임교사의 생활기록부 작성을 돕는 도우미야.
아래 자료를 바탕으로 학생 "${name}"${grade ? `(${grade})` : ""}의
'행동특성 및 종합의견' 초안을 작성해줘.

작성 지침:
- 3~6문장, 존댓말이 아닌 생활기록부 특유의 개조식/서술식 문어체(예: "~함", "~보임", "~하는 학생임").
- 학습태도·인성·교우관계·성장 과정·강점을 균형 있게, 구체적 근거(자료에 나온 사실)에 기반해서.
- 없는 사실을 지어내지 말고, 자료가 빈약하면 드러난 부분만 담백하게.
- 부정적 표현보다 성장 가능성 중심으로. 개인정보(연락처 등)는 넣지 말 것.
- 순수하게 종합의견 본문만 출력(제목·머리말·따옴표 없이).

[자료]
${attLine}${sec("관찰 누가기록", obs)}${sec("상담·생활지도", cons)}${sec("독서활동", reading)}${sec("활동/후기", writings)}`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.4, maxOutputTokens: 700 },
        }),
      },
    );

    if (!geminiRes.ok) {
      const t = await geminiRes.text();
      throw new Error(`Gemini 오류 ${geminiRes.status}: ${t.slice(0, 400)}`);
    }

    const data = await geminiRes.json();
    const draft =
      (data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") ?? "").trim();
    if (!draft) throw new Error("초안 생성에 실패했습니다");

    return new Response(JSON.stringify({ draft }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String((e as Error)?.message || e) }), {
      status: 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
