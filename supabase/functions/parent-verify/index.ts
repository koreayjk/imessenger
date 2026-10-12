// Supabase Edge Function: parent-verify
// 학부모가 가입할 때 "우리 아이가 맞는지"만 확인해 줍니다.
//
// 왜 Edge Function 인가 —
//   학생 이름 목록을 가입 화면에 띄우면, 로그인하지 않은 누구나 그 공동체
//   전교생 이름을 볼 수 있습니다. 그래서 목록은 내보내지 않고, 부모가 적은
//   이름+생년월일이 **둘 다** 맞을 때만 "찾았어요" 라고만 답합니다.
//   돌려주는 이름도 가운데를 가립니다 (홍○동). 찾지 못하면 아무 단서도
//   주지 않습니다.
//
// 이 함수는 로그인 전에 불립니다(아직 계정이 없으니까). 그래서 service_role
// 로 읽되, 돌려주는 값은 위 두 가지뿐입니다.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// 홍길동 → 홍○동 / 김민 → 김○ / Jane Doe → J*** Doe
function maskName(n: string): string {
  const s = (n || "").trim();
  if (!s) return "";
  if (/^[\p{Script=Hangul}]+$/u.test(s)) {
    if (s.length <= 2) return s[0] + "○";
    return s[0] + "○".repeat(s.length - 2) + s[s.length - 1];
  }
  return s.split(/\s+/).map((w) => (w.length <= 1 ? w : w[0] + "*".repeat(Math.min(w.length - 1, 3)))).join(" ");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { community_id, child_name, child_birth } = await req.json().catch(() => ({}));
    const name = String(child_name || "").trim();
    const birth = String(child_birth || "").trim();
    if (!community_id || !name || !birth) {
      return json({ found: false, reason: "need_all" });
    }
    // 생년월일 모양이 아니면 찾을 것도 없다 (무차별 대입으로 이름만 떠보는 걸 막는다)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(birth)) return json({ found: false, reason: "bad_birth" });

    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
    const { data, error } = await admin
      .from("members")
      .select("id, name")
      .eq("community_id", community_id)
      .eq("community_role", "student")
      .eq("birth_date", birth)
      .neq("status", "removed")
      .limit(20);
    if (error) return json({ found: false, reason: "lookup_failed" });

    // 이름은 공백·대소문자만 무시하고 정확히 맞아야 한다
    const norm = (s: string) => (s || "").replace(/\s+/g, "").toLowerCase();
    const hits = (data || []).filter((m) => norm(m.name) === norm(name));

    if (hits.length === 0) return json({ found: false, reason: "no_match" });
    // 같은 이름·같은 생일이 둘이면 사람이 골라야 한다 — 그래도 목록은 안 준다
    if (hits.length > 1) return json({ found: false, reason: "ambiguous" });

    // 학생 id 는 돌려주지 않는다. 아직 로그인도 안 한 사람이다.
    // 실제 연결은 관리자가 승인할 때 서버가 다시 찾아서 맺는다.
    return json({ found: true, masked: maskName(hits[0].name) });
  } catch (_e) {
    return json({ found: false, reason: "error" }, 200);
  }
});
