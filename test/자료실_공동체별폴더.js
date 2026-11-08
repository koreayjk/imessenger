//  📁 자료실 — 공동체마다 '자기 폴더' 만 보여야 한다
//
//  사고가 있었습니다. drive-list 가 공동체에 폴더가 없으면
//  프로젝트 전체 시크릿(DRIVE_ROOT_FOLDER_ID) 으로 되돌아갔습니다.
//  그 시크릿에 IM USA 폴더가 들어 있어서, 폴더를 등록하지 않은
//  15개 공동체(IM HQ 113명 포함) 가 전부 IM USA 자료실을 보고 있었습니다.
//
//  브라우저도 구글 드라이브도 없이, 글로 막습니다.
const fs = require('fs'), path = require('path');
const { ok, done } = require('./_harness.js');

const ROOT = path.join(__dirname, '..');
const FN   = fs.readFileSync(path.join(ROOT, 'supabase', 'functions', 'drive-list', 'index.ts'), 'utf8');
const APP  = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');

//  주석은 빼고 '코드' 만 본다. (왜 안 쓰는지 주석에 적어 두었으므로)
const CODE = FN.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');

// ── 1. 프로젝트 전체 폴더 시크릿을 아예 읽지 않는다 ──────────────
ok(!/Deno\.env\.get\(\s*["']DRIVE_ROOT_FOLDER_ID["']\s*\)/.test(CODE),
   '프로젝트 전체 폴더 시크릿(DRIVE_ROOT_FOLDER_ID) 을 읽지 않는다');
ok(!/FALLBACK_ROOT/.test(CODE),
   '되돌아갈 기본 폴더(FALLBACK_ROOT) 라는 것이 코드에 없다');

// ── 2. rootId 는 그 공동체의 칸에서만 온다 ──────────────────────
const rootLines = CODE.split('\n').filter(l => /\brootId\s*=/.test(l));
ok(rootLines.length === 1, 'rootId 를 정하는 곳이 딱 한 군데다 (찾은 곳: ' + rootLines.length + ')');
const rootLine = rootLines[0] || '';
ok(/drive_root_folder_id/.test(rootLine),
   'rootId 는 communities.drive_root_folder_id 에서 온다');
//  `|| 무엇` 으로 딴 데로 새지 않는다. (`|| ""` 는 괜찮다 — 빈 값으로 두는 것)
const tail = rootLine.split('drive_root_folder_id')[1] || '';
ok(!/\|\|\s*(?!["']\s*["'])\S/.test(tail.replace(/\.trim\(\)/g, '')),
   'rootId 에 `|| 다른폴더` 같은 되돌아가기가 붙어 있지 않다');

// ── 3. DB 에 닿지 못할 때도 폴더를 내주지 않는다 ────────────────
const noDb = CODE.slice(CODE.indexOf('!SUPABASE_URL'), CODE.indexOf('!SUPABASE_URL') + 400);
ok(/!SUPABASE_URL/.test(CODE), 'DB 에 닿지 못하는 경우를 다루는 자리가 있다');
ok(!/return\s*\{\s*rootId/.test(noDb),
   'DB 에 닿지 못하면 rootId 를 돌려주지 않는다 (어느 공동체인지 모르니까)');
ok(/throw/.test(noDb), 'DB 에 닿지 못하면 그냥 막는다');

// ── 4. 폴더가 없으면 needsFolder 로 안내한다 ────────────────────
ok(/needsFolder:\s*true/.test(CODE), '폴더가 없으면 needsFolder: true 로 답한다');
const guard = CODE.slice(CODE.indexOf('if (!rootId)'), CODE.indexOf('if (!rootId)') + 400);
ok(/needsFolder/.test(guard), '그 안내가 !rootId 바로 뒤에 붙어 있다');

// ── 5. 공동체 ID 는 넘나들 수 있는 사람만 바꿀 수 있다 ──────────
ok(/wantedCommunityId/.test(CODE), '클라이언트가 보낸 공동체 ID 를 따로 둔다');
const pick = CODE.slice(CODE.indexOf('const communityId'), CODE.indexOf('const communityId') + 300);
ok(/super_admin/.test(pick) && /vice_admin/.test(pick),
   '총관리자·부총관리자만 다른 공동체를 지정할 수 있다');
ok(/:\s*me\.community_id/.test(pick),
   '그 밖의 사람은 무조건 자기 소속 공동체다');

// ── 6. 앱은 needsFolder 를 받아서 안내 화면을 띄운다 ────────────
ok(/driveNeedsFolder\s*=\s*true/.test(APP), '앱이 needsFolder 를 받아 상태로 둔다');
ok(/renderDriveNoFolder/.test(APP), '폴더 없음 안내 화면이 있다');
ok(/공동체마다 다른 폴더/.test(APP), '안내에 공동체마다 폴더가 다르다고 적혀 있다');

// ── 7. 설치 안내가 옛 시크릿을 가리키고 있지 않다 ───────────────
//     (DRIVE_ROOT_FOLDER_ID 를 등록하라고 적혀 있으면, 또 같은 사고가 난다)
const howTo = APP.slice(APP.indexOf('function renderDriveError'), APP.indexOf('function renderDriveNoFolder'));
ok(!/DRIVE_ROOT_FOLDER_ID<\/b>/.test(howTo),
   '설치 안내가 DRIVE_ROOT_FOLDER_ID 를 등록하라고 하지 않는다');
ok(/공동체 설정/.test(howTo),
   '설치 안내가 관리자 → 공동체 설정 을 가리킨다');

done();
