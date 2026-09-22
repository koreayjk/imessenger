// Supabase Edge Function: books-search
// 구글 북스에서 책을 찾아 줍니다. 앱(index.html)의
// 운영관리 → 🎓 사역자 교육 → 자료 추가(도서) 화면에서 호출합니다.
//
// 왜 함수로 빼는가
//   브라우저에서 구글 북스를 직접 부르면 API 키가 브라우저까지 내려가서
//   개발자도구 네트워크 탭에 그대로 보입니다. 키를 서버에만 두려고 함수로 옮겼습니다.
//   키 없이 부르는 것도 가능하지만, 그때는 전 세계 익명 호출이 구글의 공용
//   프로젝트 하나를 같이 써서 429(할당량 초과)가 수시로 납니다.
//
// 필요한 Secrets (Supabase → Edge Functions → Secrets):
//   GOOGLE_BOOKS_API_KEY : Google Cloud 에서 만든 API 키 (Books API 사용 설정 필요)
//                          ※ 없으면 GOOGLE_API_KEY 를 대신 씁니다
//
// ⚠️ 이 키에는 'HTTP 리퍼러' 제한을 걸지 마세요.
//    함수는 서버에서 부르므로 리퍼러가 없어서 구글이 거부합니다.
//    API 제한은 'Books API' 만으로 좁혀 두세요. (그게 이 키의 방어선입니다)
//
// 응답은 구글이 준 items 를 그대로 넘깁니다.
// 화면에 맞게 다듬는 일은 앱에서 한 곳(gbNormalize)에서만 하도록 두려는 것입니다.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const API_KEY = ((Deno.env.get("GOOGLE_BOOKS_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY")) ?? "").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

// 로그인한 사람만 쓰게 한다. 아무나 부르면 우리 할당량을 남이 태운다.
async function requireUser(req: Request) {
  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader || !SUPABASE_URL || !ANON_KEY) return null;
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  return user ?? null;
}

// 하이픈·공백을 뗀 10/13 자리면 ISBN 으로 본다
function isbnOf(q: string) {
  const d = q.replace(/[\s-]/g, "");
  return /^(\d{9}[\dXx]|\d{13})$/.test(d) ? d : "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const user = await requireUser(req);
    if (!user) return json({ error: "로그인이 필요합니다." }, 401);

    const b = await req.json().catch(() => ({}));
    const q = String(b?.q ?? "").trim().slice(0, 200);
    if (!q) return json({ error: "검색어가 없습니다." }, 400);

    const max = Math.min(20, Math.max(1, Number(b?.max) || 10));
    const isbn = isbnOf(q);

    const p = new URLSearchParams({
      q: isbn ? `isbn:${isbn}` : q,
      maxResults: String(max),
      printType: "books",
      orderBy: "relevance",
    });
    if (API_KEY) p.set("key", API_KEY);

    const res = await fetch(`https://www.googleapis.com/books/v1/volumes?${p.toString()}`);
    const text = await res.text();
    let body: any = null;
    try { body = JSON.parse(text); } catch { /* ignore */ }

    if (!res.ok) {
      const gmsg = body?.error?.message || text.slice(0, 300);
      let msg = `구글 북스가 요청을 거부했습니다 (${res.status}). ${gmsg}`;
      if (res.status === 429) {
        msg = API_KEY
          ? "구글 북스 하루 할당량을 다 썼습니다. 내일 다시 시도하거나 구글 클라우드 콘솔에서 할당량을 올려주세요."
          : "구글 북스 할당량이 찼습니다. Supabase → Edge Functions → Secrets 에 GOOGLE_BOOKS_API_KEY 를 추가하면 전용 할당량을 씁니다.";
      } else if (res.status === 403) {
        msg = API_KEY
          ? "구글이 이 키를 거부했습니다. 키에 'Books API' 사용이 켜져 있는지, 그리고 'HTTP 리퍼러' 제한이 걸려 있지 않은지 확인하세요. (이 함수는 서버에서 호출해 리퍼러가 없습니다)"
          : "구글이 요청을 거부했습니다. GOOGLE_BOOKS_API_KEY 를 추가해 주세요.";
      }
      return json({ error: msg, status: res.status, keyed: !!API_KEY }, 400);
    }

    // 구글 원본 items 를 그대로 넘긴다 (앱에서 한 곳에서만 다듬는다)
    return json({ items: Array.isArray(body?.items) ? body.items : [], keyed: !!API_KEY });
  } catch (e: any) {
    return json({ error: String(e?.message || e) }, 400);
  }
});
