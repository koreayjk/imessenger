// Supabase Edge Function: admin-create-student
// 관리자가 학생 계정(이메일+임시비번)을 대신 생성합니다.
// 앱(index.html)의 bulkRegisterStudents() 가 학생 1명씩 호출.
// service_role 키는 Supabase가 자동 주입(SUPABASE_SERVICE_ROLE_KEY)하므로 별도 설정 불필요.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const COLORS = ["#1d3a5f","#2a5298","#6F8A5C","#5A7C8B","#7B6BA0","#2a7ab8","#B05865","#4C7363"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

    // 1) 호출자 인증 + 관리자 권한 확인
    const authHeader = req.headers.get("Authorization") || "";
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } }, auth: { persistSession: false },
    });
    const { data: { user }, error: uErr } = await userClient.auth.getUser();
    if (uErr || !user) return json({ error: "로그인이 필요합니다" }, 401);

    const { data: me } = await admin.from("members").select("community_role, community_id").eq("id", user.id).single();
    if (!me || !["super_admin", "community_admin", "admin_officer"].includes(me.community_role)) {
      return json({ error: "학생 등록 권한이 없습니다 (관리자 전용)" }, 403);
    }

    // 2) 입력값
    const b = await req.json().catch(() => ({}));
    const name = (b.name || "").toString().trim();
    const email = (b.email || "").toString().trim().toLowerCase();
    const password = (b.password || "").toString();
    const grade = (b.grade || "").toString().trim() || null;
    const community_id = (b.community_id || me.community_id);
    if (!name || !email || !password) return json({ error: "이름·이메일·비밀번호가 필요합니다" }, 400);
    if (password.length < 6) return json({ error: "비밀번호는 6자 이상이어야 합니다" }, 400);

    // 3) Auth 계정 생성 (이메일 확인 완료 처리 → 바로 로그인 가능)
    const { data: created, error: cErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { name },
    });
    if (cErr || !created?.user) {
      const msg = (cErr?.message || "").toString();
      const exists = /already|registered|exists|duplicate/i.test(msg);
      return json({ error: exists ? "이미 가입된 이메일" : (msg || "계정 생성 실패"), code: exists ? "exists" : "error" }, 200);
    }
    const uid = created.user.id;

    // 4) members 행 생성 (즉시 승인)
    const color = COLORS[Math.floor(Math.random() * COLORS.length)];
    const row: Record<string, unknown> = {
      id: uid, name, initials: name[0], color,
      role: "학생", community_role: "student",
      email, status: "approved", community_id,
    };
    if (grade) row.grade = grade;
    const { error: mErr } = await admin.from("members").insert(row);
    if (mErr) {
      // 멤버 생성 실패 시 방금 만든 Auth 계정 정리
      await admin.auth.admin.deleteUser(uid).catch(() => {});
      return json({ error: "프로필 생성 실패: " + mErr.message }, 200);
    }

    return json({ ok: true, id: uid, name, email, password });
  } catch (e) {
    return json({ error: String((e as Error)?.message || e) }, 400);
  }
});
