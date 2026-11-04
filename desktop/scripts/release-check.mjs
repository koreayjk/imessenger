//  🚦 올리기 전에 먼저 막는다
//
//  왜 있나
//    `export` 는 **그 터미널 창에서만** 삽니다. 창을 새로 열고 npm run release
//    를 치면, 빌드는 10분 넘게 돌고 나서야 이렇게 끝납니다:
//
//      • skipped macOS notarization   ← 공증 안 됨 (남들은 '손상되었습니다')
//      ⨯ GitHub Personal Access Token is not set   ← 올라가지도 않음
//
//    만든 건 dist/ 에만 남고 아무 데도 안 갑니다. 실제로 그렇게 한 번
//    날렸습니다. 그래서 **돌기 전에** 봅니다.
//
//  ⚠️ 값은 절대 찍지 않습니다. 있나 없나와 길이만 봅니다.
const env = process.env;
const has = (k) => !!(env[k] && String(env[k]).trim());

const missing = [];
const notes = [];

//  ① 올릴 자리
if (!has('GH_TOKEN') && !has('GITHUB_TOKEN')) {
  missing.push([
    'GH_TOKEN',
    '깃허브에 올릴 열쇠가 없습니다. 이 창에서:',
    '    export GH_TOKEN="$(security find-generic-password -a "$USER" -s tcs-gh-token -w)"',
    '  열쇠고리에 넣어 둔 적이 없으면 github.com → Settings → Developer settings',
    '  → Personal access tokens 에서 새로 만드세요 (Contents: Read and write).',
  ]);
}

//  ② 공증 — 열쇠고리 프로필 쪽이든, 아이디·앱암호 쪽이든 한 쪽은 있어야 한다
const byProfile = has('APPLE_KEYCHAIN_PROFILE');
const byPassword = has('APPLE_ID') && has('APPLE_APP_SPECIFIC_PASSWORD');
if (!byProfile && !byPassword) {
  missing.push([
    'APPLE_KEYCHAIN_PROFILE (또는 APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD)',
    '공증 설정이 없습니다. 이게 없으면 서명만 되고 공증이 안 돼서,',
    '  받으신 분들 맥에서 "손상되었습니다" 로 안 열립니다. 이 창에서:',
    '    export APPLE_KEYCHAIN_PROFILE="tcs-notary"',
  ]);
}
if (!has('APPLE_TEAM_ID')) {
  missing.push([
    'APPLE_TEAM_ID',
    '    export APPLE_TEAM_ID="H6B99PYZ8W"',
  ]);
}

if (byProfile) notes.push(`공증: 열쇠고리 프로필 "${env.APPLE_KEYCHAIN_PROFILE}" 을 씁니다`);
else if (byPassword) notes.push(`공증: 앱 암호를 씁니다 (길이 ${String(env.APPLE_APP_SPECIFIC_PASSWORD).length})`);
if (has('GH_TOKEN') || has('GITHUB_TOKEN')) {
  const tok = env.GH_TOKEN || env.GITHUB_TOKEN;
  notes.push(`깃허브 열쇠: 있습니다 (길이 ${String(tok).length})`);
}

if (missing.length) {
  console.error('\n🚦 올리기 전에 막았습니다 — 아래가 없으면 10분 빌드가 헛돕니다.\n');
  for (const [name, ...lines] of missing) {
    console.error(`  ❌ ${name}`);
    for (const l of lines) console.error(`     ${l}`);
    console.error('');
  }
  console.error('  자세한 것은 docs/맥앱_dmg_만들기.md 를 보세요.\n');
  process.exit(1);
}

console.log('\n🚦 올릴 준비가 됐습니다');
for (const n of notes) console.log(`   · ${n}`);
console.log('');
