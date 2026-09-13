// Supabase Edge Function: delete-account
// 본인이 자기 계정을 지웁니다. 앱의 [내 정보 → 계정 삭제] 에서 부릅니다.
//
// Google Play 는 로그인이 있는 앱에 "앱 안에서 계정을 지우는 길"을 요구합니다.
// 웹 안내 페이지(delete-account.html)만으로는 부족하고, 앱 안에도 있어야 합니다.
//
// 순서가 중요합니다:
//   1) 지우기 전에 첨부파일 경로부터 모은다 (메시지를 먼저 지우면 경로를 잃는다)
//   2) DB 정리는 delete_my_account() 에 맡긴다  → db/계정삭제_DB설치.sql
//   3) 저장소 파일을 지운다
//   4) 마지막으로 로그인 계정 자체를 지운다
//
// 4번이 실패해도 이미 로그인은 막힌 상태입니다(members.status='removed').
// 그래서 실패를 통째로 되돌리지 않고, 어디까지 됐는지 그대로 알려 줍니다.
//
// 필요한 Secrets: 없음 (SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY 는 자동 주입)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const BUCKET = "messenger";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// 메시지 본문에 박혀 있는 공개 URL 에서 버킷 안 경로만 뽑아낸다.
//   …/storage/v1/object/public/messenger/chat/<채널>/<파일>  →  chat/<채널>/<파일>
function attachmentPaths(text: string): string[] {
  const out: string[] = [];
  const re = new RegExp(
    `/storage/v1/object/(?:public|sign)/${BUCKET}/([^"'\\\\\\s?)\\]]+)`,
    "g",
  );
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) {
    try { out.push(decodeURIComponent(m[1])); } catch { out.push(m[1]); }
  }
  return out;
}

// notes/<uid>/ 아래 파일을 전부 훑는다 (한 번에 100개씩)
async function listUserNoteFiles(admin: any, uid: string): Promise<string[]> {
  const prefix = `notes/${uid}`;
  const found: string[] = [];
  for (let offset = 0; offset < 5000; offset += 100) {
    const { data, error } = await admin.storage.from(BUCKET).list(prefix, { limit: 100, offset });
    if (error || !data || data.length === 0) break;
    for (const f of data) if (f.name) found.push(`${prefix}/${f.name}`);
    if (data.length < 100) break;
  }
  return found;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST 로 호출해 주세요." }, 405);

  if (!SUPABASE_URL || !SERVICE_KEY) {
    return json({ error: "서버 설정이 빠져 있습니다. (SERVICE_ROLE_KEY)" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "로그인이 필요합니다." }, 401);
  }

  // 호출자 본인 자격 — auth.uid() 가 여기서 결정된다
  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  const uid = userData?.user?.id;
  if (userErr || !uid) return json({ error: "로그인 정보를 확인할 수 없습니다." }, 401);

  // 되돌릴 수 없는 작업이므로, 앱이 확인 문구를 함께 보내야 실행한다.
  let body: any = {};
  try { body = await req.json(); } catch { /* 본문 없음 */ }
  if (body?.confirm !== "DELETE") {
    return json({ error: "확인 값이 없습니다." }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const report: Record<string, unknown> = {};

  // ── 1. 지우기 전에 첨부파일 경로부터 모은다 ──────────────────────
  const paths = new Set<string>();
  try {
    const { data: msgs } = await admin
      .from("messages").select("text").eq("sender_id", uid).limit(5000);
    for (const m of msgs ?? []) {
      for (const p of attachmentPaths(String(m?.text ?? ""))) paths.add(p);
    }
  } catch { /* messages 가 없거나 형식이 달라도 계속 진행 */ }

  try {
    for (const p of await listUserNoteFiles(admin, uid)) paths.add(p);
  } catch { /* 저장소 조회 실패해도 계속 */ }

  // 남의 파일을 지우지 않도록 — 내 노트 폴더이거나, 파일명에 내 id 가 박힌 것만
  const mine = [...paths].filter(
    (p) => p.startsWith(`notes/${uid}/`) || p.includes(uid),
  );

  // ── 2. DB 정리 (본인 자격으로 호출해야 auth.uid() 가 잡힌다) ─────
  const { data: rpcData, error: rpcErr } = await asUser.rpc("delete_my_account");
  if (rpcErr) {
    const msg = rpcErr.message || "";
    // 총관리자 차단은 사용자에게 그대로 보여 준다
    const blocked = msg.includes("총관리자");
    return json({ error: blocked ? msg : `기록을 지우지 못했습니다: ${msg}` }, blocked ? 409 : 500);
  }
  report.db = rpcData;

  // ── 3. 저장소 파일 ──────────────────────────────────────────────
  if (mine.length) {
    try {
      for (let i = 0; i < mine.length; i += 100) {
        await admin.storage.from(BUCKET).remove(mine.slice(i, i + 100));
      }
      report.files = mine.length;
    } catch { report.files = "일부 실패"; }
  } else {
    report.files = 0;
  }

  // ── 4. 로그인 계정 ──────────────────────────────────────────────
  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) {
    // 여기서 실패해도 이미 기록은 지워졌고 로그인은 막혀 있다.
    report.auth = `남아 있음 (${delErr.message})`;
    return json({
      ok: true,
      partial: true,
      message: "기록은 모두 지워졌고 로그인은 차단되었습니다. 로그인 계정 자체는 운영자가 확인 후 제거합니다.",
      report,
    });
  }
  report.auth = "deleted";

  return json({ ok: true, message: "계정이 삭제되었습니다.", report });
});
