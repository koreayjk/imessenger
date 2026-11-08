// Supabase Edge Function: drive-list
// 구글 드라이브의 '지정된 루트 폴더' 아래를 탐색해 목록을 돌려줍니다.
// 앱(index.html)의 자료실 화면에서 호출합니다.
//
// 루트 폴더는 공동체마다 다릅니다 (communities.drive_root_folder_id).
// 시크릿은 프로젝트 전체에 하나뿐이라 공동체별로 나눌 수 없어서,
// 폴더 ID 는 DB 에 두고 호출자의 토큰으로 소속 공동체를 서버에서 판단합니다.
// (클라이언트가 보내는 공동체 ID 를 그대로 믿으면 남의 공동체 폴더를 열 수 있습니다)
//
// 필요한 Secrets (Edge Functions → Secrets):
//   DRIVE_API_KEY         : Google Cloud 에서 만든 API 키 (Drive API 사용 설정 필요)
//                           ※ 없으면 GOOGLE_API_KEY 를 대신 사용합니다
//
// ※ 공동체에 폴더가 지정되지 않았으면 '아직 지정되지 않았습니다' 라고 답합니다.
//   예전에는 DRIVE_ROOT_FOLDER_ID 시크릿으로 되돌아갔는데, 그러면 폴더를 등록하지 않은
//   공동체가 전부 남의 공동체 자료실을 보게 됩니다. 그래서 되돌아가지 않습니다.
//
// 자료실은 두 칸입니다.
//   🏠 우리 공동체  : communities.drive_root_folder_id
//   🌐 전체 공용    : app_settings.drive_shared_folder_id_<종류> (총관리자만 정함)
//                     종류마다 따로 둡니다 — 리뉴젠 공동체 그룹과 리뉴젠
//                     아카데미 그룹이 서로 다른 자료실을 봅니다.
// 요청의 scope 가 "shared" 면 공동체를 따지지 않고 전체 공용 폴더를 엽니다.
//
// 폴더는 '링크가 있는 모든 사용자 - 뷰어' 로 공유되어 있어야 합니다.
//
// ※ API 키만으로 접근하면 구글이 parents(상위 폴더) 정보를 주지 않습니다.
//   그래서 상위로 거슬러 올라가지 않고, 루트에서 경로를 따라 내려가며 검증합니다.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const API_KEY = ((Deno.env.get("DRIVE_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY")) ?? "").trim();
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const FOLDER_MIME = "application/vnd.google-apps.folder";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DRIVE = "https://www.googleapis.com/drive/v3";
const COMMON = `key=${encodeURIComponent(API_KEY)}&supportsAllDrives=true&includeItemsFromAllDrives=true`;
const esc = (s: string) => String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'");

async function driveGet(path: string): Promise<any> {
  const res = await fetch(`${DRIVE}${path}`);
  const text = await res.text();
  let body: any = null;
  try { body = JSON.parse(text); } catch { /* ignore */ }
  if (!res.ok) {
    const err: any = new Error(body?.error?.message || text.slice(0, 300));
    err.status = res.status;
    throw err;
  }
  return body;
}

const FILE_FIELDS = "id,name,mimeType,size,modifiedTime,webViewLink,thumbnailLink";

// 한 폴더의 바로 아래 항목 (페이지 전부 모음)
async function listChildren(folderId: string, foldersOnly = false): Promise<any[]> {
  const out: any[] = [];
  let pageToken = "";
  for (let i = 0; i < 10; i++) {
    const p = new URLSearchParams({
      q: `'${esc(folderId)}' in parents and trashed = false` + (foldersOnly ? ` and mimeType = '${FOLDER_MIME}'` : ""),
      fields: `nextPageToken, files(${FILE_FIELDS})`,
      pageSize: "200",
      orderBy: "folder,name",
    });
    if (pageToken) p.set("pageToken", pageToken);
    const data = await driveGet(`/files?${p.toString()}&${COMMON}`);
    out.push(...(data?.files || []));
    pageToken = data?.nextPageToken || "";
    if (!pageToken) break;
  }
  return out;
}

// 루트에서 경로를 따라 내려가며 각 단계가 실제 하위 폴더인지 확인
// 반환: 브레드크럼 [{id,name}, ...] (루트 포함)
async function walkPath(rootId: string, path: string[]): Promise<{ id: string; name: string }[]> {
  let rootName = "";
  try {
    const meta = await driveGet(`/files/${encodeURIComponent(rootId)}?fields=id,name&${COMMON}`);
    rootName = meta?.name || "";
  } catch { rootName = ""; }

  const crumbs = [{ id: rootId, name: rootName }];
  let cur = rootId;
  for (const want of path.slice(0, 15)) {
    if (!want || want === rootId) continue;
    const kids = await listChildren(cur, true);
    const hit = kids.find((k: any) => k.id === want);
    if (!hit) { const e: any = new Error("PATH"); e.status = 403; throw e; }
    crumbs.push({ id: hit.id, name: hit.name || "" });
    cur = hit.id;
  }
  return crumbs;
}

// 검색 범위를 루트 하위로 제한하기 위해 폴더 목록을 모은다 (개수 제한)
async function collectFolders(rootId: string, maxFolders = 60): Promise<string[]> {
  const ids = [rootId];
  const queue = [rootId];
  while (queue.length && ids.length < maxFolders) {
    const cur = queue.shift()!;
    let kids: any[] = [];
    try { kids = await listChildren(cur, true); } catch { kids = []; }
    for (const k of kids) {
      if (ids.length >= maxFolders) break;
      if (!ids.includes(k.id)) { ids.push(k.id); queue.push(k.id); }
    }
  }
  return ids;
}

function shape(f: any) {
  const isFolder = f.mimeType === FOLDER_MIME;
  return {
    id: f.id,
    name: f.name,
    isFolder,
    mimeType: f.mimeType,
    size: f.size ? Number(f.size) : null,
    modifiedTime: f.modifiedTime || "",
    viewUrl: f.webViewLink || `https://drive.google.com/file/d/${f.id}/view`,
    downloadUrl: isFolder ? "" : `https://drive.google.com/uc?export=download&id=${f.id}`,
    thumb: f.thumbnailLink || "",
  };
}

// 호출자의 토큰으로 소속 공동체를 확인하고, 그 공동체의 루트 폴더를 돌려준다.
// 총관리자만 다른 공동체를 명시해 열 수 있다 (앱의 공동체 전환 기능 때문).
//
// scope = "shared" 면 공동체를 따지지 않고 '전체 공용 폴더' 를 돌려준다.
// 그 폴더는 app_settings 에 종류별로 하나씩 있고,
// **일부러 모두에게 보여주는** 폴더다 (총관리자만 정한다).
async function resolveRoot(req: Request, wantedCommunityId: string, scope: string) {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    // DB 에 닿지 못하면 어느 공동체인지 알 수 없다. 모르면 아무것도 열지 않는다.
    const e: any = new Error("서버 설정이 끝나지 않았습니다. 잠시 뒤 다시 시도해 주세요.");
    e.status = 503;
    throw e;
  }
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const authHeader = req.headers.get("Authorization") || "";
  const userClient = createClient(SUPABASE_URL, ANON_KEY || SERVICE_KEY, {
    global: { headers: { Authorization: authHeader } }, auth: { persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) { const e: any = new Error("로그인이 필요합니다"); e.status = 401; throw e; }

  const { data: me } = await admin.from("members")
    .select("community_id, community_role").eq("id", user.id).single();
  if (!me) { const e: any = new Error("공동체 정보를 찾을 수 없습니다"); e.status = 403; throw e; }

  // 클라이언트가 보낸 공동체 ID 는 공동체를 넘나들 수 있는 사람만 인정
  // (총관리자 · 부총관리자. 부총관리자는 읽기만 하지만 '보는 곳'이 따라와야 한다)
  const communityId = ((me.community_role === "super_admin" || me.community_role === "vice_admin") && wantedCommunityId) ? wantedCommunityId : me.community_id;

  const { data: comm } = await admin.from("communities")
    .select("drive_root_folder_id, name, kind").eq("id", communityId).single();

  // ── 🌐 전체 공용 폴더 ──
  //  종류마다 **따로** 둔다. 리뉴젠 공동체 그룹과 리뉴젠 아카데미 그룹이
  //  서로 다른 자료실을 본다. 보고 있는 공동체의 종류를 따른다
  //  (총·부총관리자가 공동체를 바꾸면 그 종류의 공용 폴더가 보인다).
  if (scope === "shared") {
    const kind = ((comm as any)?.kind === "academy") ? "academy" : "community";
    const { data: st } = await admin.from("app_settings")
      .select("value").eq("key", "drive_shared_folder_id_" + kind).maybeSingle();
    return {
      rootId: String((st as any)?.value || "").trim(),
      communityId,
      role: me.community_role,
      communityName: "",
      scope: "shared",
      sharedKind: kind,
    };
  }
  // 이 공동체에 지정된 폴더만 쓴다. 없으면 빈 값 → 호출부에서 needsFolder 로 안내한다.
  const rootId = String((comm as any)?.drive_root_folder_id || "").trim();
  return { rootId, communityId, role: me.community_role,
           communityName: (comm as any)?.name || "", scope: "mine",
           sharedKind: ((comm as any)?.kind === "academy") ? "academy" : "community" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!API_KEY) {
      return json({ error: "드라이브 API 키가 없습니다. Supabase → Edge Functions → Secrets 에 DRIVE_API_KEY 를 추가하세요." }, 400);
    }

    const b = await req.json().catch(() => ({}));
    const search = (b.search || "").toString().trim();
    const path: string[] = Array.isArray(b.path) ? b.path.map((x: any) => String(x || "").trim()).filter(Boolean) : [];

    const wantScope = (String(b.scope || "mine").trim() === "shared") ? "shared" : "mine";
    const { rootId, communityName, scope, sharedKind } = await resolveRoot(req, String(b.communityId || "").trim(), wantScope);
    const kindKo = sharedKind === "academy" ? "리뉴젠 아카데미" : "리뉴젠 공동체";
    if (!rootId) {
      return json({
        error: scope === "shared"
          ? `${kindKo} 그룹의 전체 공용 자료실 폴더가 아직 지정되지 않았습니다. 총관리자가 관리자 → 공동체 에서 등록해야 합니다.`
          : "이 공동체의 자료실 폴더가 아직 지정되지 않았습니다. 관리자 → 공동체 설정 에서 구글 드라이브 폴더 ID 를 등록해 주세요.",
        needsFolder: true,
        scope,
        sharedKind,
      }, 400);
    }

    // ── 검색: 루트 하위 폴더들 안에서만 이름 검색 ──
    if (search) {
      const folderIds = await collectFolders(rootId);
      const parentsQ = folderIds.map((id) => `'${esc(id)}' in parents`).join(" or ");
      const p = new URLSearchParams({
        q: `name contains '${esc(search)}' and trashed = false and (${parentsQ})`,
        fields: `files(${FILE_FIELDS})`,
        pageSize: "100",
        orderBy: "folder,name",
      });
      const data = await driveGet(`/files?${p.toString()}&${COMMON}`);
      return json({
        v: 5,
        scope,
        sharedKind,
        rootId,
        folderId: rootId,
        communityName,
        files: (data?.files || []).map(shape),
        breadcrumb: [],
        searchScopeLimited: folderIds.length >= 60,
      });
    }

    // ── 폴더 열기: 루트에서 경로를 따라 내려가며 검증 ──
    const breadcrumb = await walkPath(rootId, path);
    const folderId = breadcrumb[breadcrumb.length - 1].id;
    const files = (await listChildren(folderId)).map(shape);

    return json({ v: 5, scope, sharedKind, rootId, folderId, communityName, files, breadcrumb });
  } catch (e: any) {
    const status = e?.status;
    let msg = String(e?.message || e);
    if (status === 401 || status === 503 || (status === 403 && /로그인|공동체 정보/.test(msg))) {
      return json({ error: msg }, status);
    }
    if (status === 403 && msg === "PATH") {
      msg = "폴더 경로를 확인하지 못했습니다. 자료실을 새로고침한 뒤 다시 열어주세요.";
    } else if (status === 404) {
      msg = "폴더를 찾을 수 없습니다. 공동체 설정의 폴더 ID 가 맞는지, 폴더가 '링크가 있는 모든 사용자'로 공유되었는지 확인하세요.";
    } else if (status === 403) {
      msg = `구글이 요청을 거부했습니다. API 키에 Drive API 사용이 켜져 있는지 확인하세요. 상세: ${msg}`;
    }
    return json({ error: msg }, 400);
  }
});
