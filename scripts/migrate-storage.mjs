// Supabase Storage 파일 이전: 구 프로젝트 → 새 프로젝트
// 실행: 환경변수 4개를 인라인으로 넘겨 한 번에 실행 (터미널 변수 불필요)
//
//   cd ~/supabase-migrate
//   npm install @supabase/supabase-js
//   OLD_URL=https://epzzpabzhahguulnsttp.supabase.co \
//   OLD_KEY=<구 service_role 키> \
//   NEW_URL=https://bbfvnmlrdtzmcwfadjqw.supabase.co \
//   NEW_KEY=<신 service_role 키> \
//   node migrate-storage.mjs
//
//  ※ service_role 키: 각 프로젝트 대시보드 → Settings → API → service_role (secret)
//    이 키는 본인 컴퓨터에서만 쓰고, 외부에 공유하지 마세요.

import { createClient } from "@supabase/supabase-js";

const { OLD_URL, OLD_KEY, NEW_URL, NEW_KEY } = process.env;
if (!OLD_URL || !OLD_KEY || !NEW_URL || !NEW_KEY) {
  console.error("환경변수 OLD_URL / OLD_KEY / NEW_URL / NEW_KEY 가 필요합니다.");
  process.exit(1);
}

const OLD = createClient(OLD_URL, OLD_KEY, { auth: { persistSession: false } });
const NEW = createClient(NEW_URL, NEW_KEY, { auth: { persistSession: false } });

let copied = 0, failed = 0, skipped = 0;

async function copyFolder(bucket, prefix) {
  const { data: items, error } = await OLD.storage.from(bucket).list(prefix, {
    limit: 1000,
    sortBy: { column: "name", order: "asc" },
  });
  if (error) { console.error(`  list 실패 [${bucket}/${prefix}]: ${error.message}`); return; }

  for (const it of items) {
    const path = prefix ? `${prefix}/${it.name}` : it.name;
    if (it.id === null) {
      // 폴더 → 재귀
      await copyFolder(bucket, path);
      continue;
    }
    const { data: blob, error: dErr } = await OLD.storage.from(bucket).download(path);
    if (dErr) { console.error(`  ✗ 다운로드 실패 ${path}: ${dErr.message}`); failed++; continue; }
    const buf = Buffer.from(await blob.arrayBuffer());
    const { error: uErr } = await NEW.storage.from(bucket).upload(path, buf, {
      contentType: it.metadata?.mimetype || "application/octet-stream",
      upsert: true,
    });
    if (uErr) { console.error(`  ✗ 업로드 실패 ${path}: ${uErr.message}`); failed++; }
    else { console.log(`  ✓ ${bucket}/${path}`); copied++; }
  }
}

const { data: buckets, error: bErr } = await OLD.storage.listBuckets();
if (bErr) { console.error("버킷 목록 실패:", bErr.message); process.exit(1); }
console.log(`버킷 ${buckets.length}개 발견:`, buckets.map(b => b.name).join(", "));

for (const b of buckets) {
  console.log(`\n[버킷] ${b.name} (public=${b.public}) 복사 시작...`);
  // 새 프로젝트에 버킷 없으면 생성 (이미 있으면 무시)
  const { error: cErr } = await NEW.storage.createBucket(b.id, {
    public: b.public,
    fileSizeLimit: b.file_size_limit ?? undefined,
    allowedMimeTypes: b.allowed_mime_types ?? undefined,
  });
  if (cErr && !/already exists/i.test(cErr.message)) console.warn(`  (버킷 생성 경고: ${cErr.message})`);
  await copyFolder(b.id, "");
}

console.log(`\n==== 완료: 복사 ${copied} / 실패 ${failed} / 건너뜀 ${skipped} ====`);
