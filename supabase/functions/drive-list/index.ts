// Supabase Edge Function: drive-list
// 구글 드라이브의 '지정된 루트 폴더' 아래를 탐색해 목록을 돌려줍니다.
// 앱(index.html)의 드라이브 화면에서 호출합니다.
//
// 필요한 Secrets (Edge Functions → drive-list → Secrets):
//   DRIVE_API_KEY         : Google Cloud 에서 만든 API 키 (Drive API 사용 설정 필요)
//                           ※ 없으면 GOOGLE_API_KEY 를 대신 사용합니다
//   DRIVE_ROOT_FOLDER_ID  : 공유할 최상위 폴더 ID (드라이브 폴더 URL 의 마지막 부분)
//
// 폴더는 '링크가 있는 모든 사용자 - 뷰어' 로 공유되어 있어야 합니다.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// DRIVE_API_KEY 를 우선 사용하고, 없으면 GOOGLE_API_KEY 를 씁니다.
// (Supabase Secrets 는 프로젝트 전체 공용이라 기존 키와 충돌하지 않도록 분리 가능)
const API_KEY = ((Deno.env.get("DRIVE_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY")) ?? "").trim();
const ROOT_ID = (Deno.env.get("DRIVE_ROOT_FOLDER_ID") ?? "").trim();
const FOLDER_MIME = "application/vnd.google-apps.folder";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const DRIVE = "https://www.googleapis.com/drive/v3";
const COMMON = `key=${encodeURIComponent(API_KEY)}&supportsAllDrives=true`;

async function driveGet(path: string): Promise<any> {
  const res = await fetch(`${DRIVE}${path}`);
  const text = await res.text();
  let body: any = null;
  try { body = JSON.parse(text); } catch { /* ignore */ }
  if (!res.ok) {
    const msg = body?.error?.message || text.slice(0, 300);
    const err: any = new Error(msg);
    err.status = res.status;
    throw err;
  }
  return body;
}

// 요청한 폴더가 정말 루트 폴더 하위인지 확인 (다른 공개 폴더 열람 방지)
async function isInsideRoot(folderId: string): Promise<boolean> {
  if (folderId === ROOT_ID) return true;
  let cur = folderId;
  for (let depth = 0; depth < 15; depth++) {
    const meta = await driveGet(`/files/${encodeURIComponent(cur)}?fields=id,parents&${COMMON}`);
    const parents: string[] = meta?.parents || [];
    if (!parents.length) return false;
    if (parents.includes(ROOT_ID)) return true;
    cur = parents[0];
  }
  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!API_KEY) {
      return json({ error: "드라이브 API 키가 없습니다. Supabase → Edge Functions → Secrets 에 DRIVE_API_KEY (또는 GOOGLE_API_KEY) 를 추가하세요." }, 400);
    }
    if (!ROOT_ID) {
      return json({ error: "DRIVE_ROOT_FOLDER_ID 가 설정되지 않았습니다. 공유할 구글 드라이브 폴더 ID 를 Secrets 에 추가하세요." }, 400);
    }

    const b = await req.json().catch(() => ({}));
    const folderId = (b.folderId || ROOT_ID).toString().trim();
    const search = (b.search || "").toString().trim();
    const pageToken = (b.pageToken || "").toString().trim();

    if (folderId !== ROOT_ID && !(await isInsideRoot(folderId))) {
      return json({ error: "이 폴더는 공유 대상이 아닙니다." }, 403);
    }

    // 검색이면 루트 하위 전체에서 이름 검색, 아니면 해당 폴더의 바로 아래 항목
    const esc = (s: string) => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
    const q = search
      ? `name contains '${esc(search)}' and trashed = false`
      : `'${esc(folderId)}' in parents and trashed = false`;

    const params = new URLSearchParams({
      q,
      fields: "nextPageToken, files(id,name,mimeType,size,modifiedTime,webViewLink,thumbnailLink)",
      pageSize: "200",
      orderBy: search ? "name" : "folder,name",
      includeItemsFromAllDrives: "true",
    });
    if (pageToken) params.set("pageToken", pageToken);

    const data = await driveGet(`/files?${params.toString()}&${COMMON}`);
    const files = (data?.files || []).map((f: any) => ({
      id: f.id,
      name: f.name,
      isFolder: f.mimeType === FOLDER_MIME,
      mimeType: f.mimeType,
      size: f.size ? Number(f.size) : null,
      modifiedTime: f.modifiedTime || "",
      viewUrl: f.webViewLink || `https://drive.google.com/file/d/${f.id}/view`,
      downloadUrl: f.mimeType === FOLDER_MIME ? "" : `https://drive.google.com/uc?export=download&id=${f.id}`,
      thumb: f.thumbnailLink || "",
    }));

    // 현재 폴더 이름 + 상위 경로(브레드크럼)
    let breadcrumb: { id: string; name: string }[] = [];
    if (!search) {
      try {
        let cur = folderId;
        for (let depth = 0; depth < 15; depth++) {
          const meta = await driveGet(`/files/${encodeURIComponent(cur)}?fields=id,name,parents&${COMMON}`);
          breadcrumb.unshift({ id: meta.id, name: meta.name || "" });
          if (meta.id === ROOT_ID) break;
          const parents: string[] = meta?.parents || [];
          if (!parents.length) break;
          cur = parents[0];
        }
      } catch { breadcrumb = []; }
    }

    return json({ rootId: ROOT_ID, folderId, files, breadcrumb, nextPageToken: data?.nextPageToken || "" });
  } catch (e: any) {
    const status = e?.status;
    let msg = String(e?.message || e);
    if (status === 404) msg = "폴더를 찾을 수 없습니다. 폴더 ID 가 맞는지, 폴더가 '링크가 있는 모든 사용자'로 공유되었는지 확인하세요.";
    else if (status === 403) msg = `구글이 요청을 거부했습니다. API 키에 Drive API 사용이 켜져 있는지, 폴더 공유 설정이 맞는지 확인하세요. 상세: ${msg}`;
    return json({ error: msg }, 400);
  }
});
