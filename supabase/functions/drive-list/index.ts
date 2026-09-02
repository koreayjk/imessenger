// Supabase Edge Function: drive-list
// 구글 드라이브의 '지정된 루트 폴더' 아래를 탐색해 목록을 돌려줍니다.
// 앱(index.html)의 자료실 화면에서 호출합니다.
//
// 필요한 Secrets (Edge Functions → Secrets):
//   DRIVE_API_KEY         : Google Cloud 에서 만든 API 키 (Drive API 사용 설정 필요)
//                           ※ 없으면 GOOGLE_API_KEY 를 대신 사용합니다
//   DRIVE_ROOT_FOLDER_ID  : 공유할 최상위 폴더 ID (드라이브 폴더 URL 의 마지막 부분)
//
// 폴더는 '링크가 있는 모든 사용자 - 뷰어' 로 공유되어 있어야 합니다.
//
// ※ API 키만으로 접근하면 구글이 parents(상위 폴더) 정보를 주지 않습니다.
//   그래서 상위로 거슬러 올라가지 않고, 루트에서 경로를 따라 내려가며 검증합니다.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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
async function walkPath(path: string[]): Promise<{ id: string; name: string }[]> {
  let rootName = "";
  try {
    const meta = await driveGet(`/files/${encodeURIComponent(ROOT_ID)}?fields=id,name&${COMMON}`);
    rootName = meta?.name || "";
  } catch { rootName = ""; }

  const crumbs = [{ id: ROOT_ID, name: rootName }];
  let cur = ROOT_ID;
  for (const want of path.slice(0, 15)) {
    if (!want || want === ROOT_ID) continue;
    const kids = await listChildren(cur, true);
    const hit = kids.find((k: any) => k.id === want);
    if (!hit) { const e: any = new Error("PATH"); e.status = 403; throw e; }
    crumbs.push({ id: hit.id, name: hit.name || "" });
    cur = hit.id;
  }
  return crumbs;
}

// 검색 범위를 루트 하위로 제한하기 위해 폴더 목록을 모은다 (개수 제한)
async function collectFolders(maxFolders = 60): Promise<string[]> {
  const ids = [ROOT_ID];
  const queue = [ROOT_ID];
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    if (!API_KEY) {
      return json({ error: "드라이브 API 키가 없습니다. Supabase → Edge Functions → Secrets 에 DRIVE_API_KEY 를 추가하세요." }, 400);
    }
    if (!ROOT_ID) {
      return json({ error: "DRIVE_ROOT_FOLDER_ID 가 설정되지 않았습니다. 공유할 폴더 ID 를 Secrets 에 추가하세요." }, 400);
    }

    const b = await req.json().catch(() => ({}));
    const search = (b.search || "").toString().trim();
    const path: string[] = Array.isArray(b.path) ? b.path.map((x: any) => String(x || "").trim()).filter(Boolean) : [];

    // ── 검색: 루트 하위 폴더들 안에서만 이름 검색 ──
    if (search) {
      const folderIds = await collectFolders();
      const parentsQ = folderIds.map((id) => `'${esc(id)}' in parents`).join(" or ");
      const p = new URLSearchParams({
        q: `name contains '${esc(search)}' and trashed = false and (${parentsQ})`,
        fields: `files(${FILE_FIELDS})`,
        pageSize: "100",
        orderBy: "folder,name",
      });
      const data = await driveGet(`/files?${p.toString()}&${COMMON}`);
      return json({
        rootId: ROOT_ID,
        folderId: ROOT_ID,
        files: (data?.files || []).map(shape),
        breadcrumb: [],
        searchScopeLimited: folderIds.length >= 60,
      });
    }

    // ── 폴더 열기: 루트에서 경로를 따라 내려가며 검증 ──
    const breadcrumb = await walkPath(path);
    const folderId = breadcrumb[breadcrumb.length - 1].id;
    const files = (await listChildren(folderId)).map(shape);

    return json({ rootId: ROOT_ID, folderId, files, breadcrumb });
  } catch (e: any) {
    const status = e?.status;
    let msg = String(e?.message || e);
    if (status === 403 && msg === "PATH") {
      msg = "폴더 경로를 확인하지 못했습니다. 자료실을 새로고침한 뒤 다시 열어주세요.";
    } else if (status === 404) {
      msg = "폴더를 찾을 수 없습니다. DRIVE_ROOT_FOLDER_ID 가 맞는지, 폴더가 '링크가 있는 모든 사용자'로 공유되었는지 확인하세요.";
    } else if (status === 403) {
      msg = `구글이 요청을 거부했습니다. API 키에 Drive API 사용이 켜져 있는지 확인하세요. 상세: ${msg}`;
    }
    return json({ error: msg }, 400);
  }
});
