// www/ 를 만든다 — 아이폰 앱 안에 들어갈 파일만 골라 담는다.
//
//  애플은 "웹사이트를 그대로 포장한 앱"(지침 4.2)을 거부합니다.
//  그래서 원격 주소를 띄우는 대신, 화면을 앱 안에 넣고 돌립니다.
//  비행기 모드에서도 앱이 뜨고, 심사 중에 사이트가 흔들려도 앱은 멀쩡합니다.
//  대신 화면을 고치면 App Store 에 새 버전을 올려야 반영됩니다.
//
//  db/ · twa/ · docs/ · brand 의 작업 파일처럼 앱이 쓰지 않는 것은 뺍니다.
//  (1.7MB 짜리 index.html 하나에 다 들어 있어서 담을 게 많지 않습니다)
import { cp, mkdir, rm, stat } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const OUT  = join(ROOT, 'www');

const FILES = [
  'index.html',
  'store.html',
  'terms.html',              // 개인정보처리방침 — 설정에서 연다
  'delete-account.html',     // 계정 삭제 안내 — 애플도 요구한다
  'manifest.webmanifest',
  'apple-touch-icon.png',
  'favicon.png',
  'tcs_logo.png',
  'tcs_icon.png',
  'tcs_icon-192.png',
  'tcs_icon-512.png',
  'tcs_icon-maskable-192.png',
  'tcs_icon-maskable-512.png',
  'brand/tcs-logo-vertical-dark.svg',
];

await rm(OUT, { recursive: true, force: true });
await mkdir(OUT, { recursive: true });

let n = 0, missing = [];
for (const f of FILES) {
  try {
    await stat(join(ROOT, f));
  } catch { missing.push(f); continue; }
  await mkdir(dirname(join(OUT, f)), { recursive: true });
  await cp(join(ROOT, f), join(OUT, f));
  n++;
}

console.log(`www/ 에 ${n}개 담음`);
if (missing.length) {
  // 조용히 넘어가면 앱에서 깨진 아이콘이 보인다. 빌드를 멈춘다.
  console.error('❌ 없는 파일:', missing.join(', '));
  process.exit(1);
}
