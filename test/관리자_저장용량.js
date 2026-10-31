//  💾 관리 → 저장 용량 — 무엇이 자리를 차지하는지 보고 지우는가
//
//  '어디에 얼마나' 만 보여서는 가득 찼을 때 치울 길이 없었습니다.
//  그리고 지우기는 되돌릴 수 없으므로, 묻지 않고 지우면 안 됩니다.
//
//  ⚠️ 규칙(RLS)에 막히면 지우기는 **오류 없이 0개**를 돌려줍니다.
//     '지웠습니다' 라고 말해 버리면 안 지워진 줄도 모릅니다.
const { launch, openApp, ok, done } = require('./_harness.js');

const FILES = [
  { '경로':'chat/ch1/video.mp4', '폴더':'chat', '갈래':'채팅 사진·파일', '크기':91000000, '형식':'video/mp4',  '올린때':'2026-10-02T03:00:00Z' },
  { '경로':'chat/ch1/photo.jpg', '폴더':'chat', '갈래':'채팅 사진·파일', '크기':2400000,  '형식':'image/jpeg', '올린때':'2026-10-20T03:00:00Z' },
  { '경로':'orgs/c1/logo.png',   '폴더':'orgs', '갈래':'기관 로고',      '크기':675000,   '형식':'image/png',  '올린때':'2026-09-01T03:00:00Z' },
  { '경로':'notes/me/memo.pdf',  '폴더':'notes','갈래':'IM노트 첨부',    '크기':120000,   '형식':'application/pdf', '올린때':'2026-08-01T03:00:00Z' },
];

const seed = (pg) => pg.evaluate((f) => {
  window.__DB['rpc:community_storage_files']  = f;
  window.__DB['rpc:community_storage_one']    = [{ '사용 바이트': 94195000, '한도 MB': 5120, '볼 수 있음': true }];
  window.__DB['rpc:community_storage_detail'] = [{ '갈래':'채팅 사진·파일', '사용 바이트':93400000, '파일 수':2 },
                                                 { '갈래':'기관 로고', '사용 바이트':675000, '파일 수':1 }];
}, FILES);

const cards = (pg) => pg.evaluate(() => [...document.querySelectorAll('#sf-list .sf-card')].map(c => ({
  txt: c.textContent.replace(/\s+/g, ' ').trim(),
  img: !!c.querySelector('img.sf-thumb'),
  href: (c.querySelector('a') || {}).getAttribute ? c.querySelector('a').getAttribute('href') : '',
})));

(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'teacher' });
  let asked = '';
  pg.on('dialog', (d) => { asked = d.message(); d.accept(); });
  await seed(pg);

  await pg.evaluate(() => switchAdminTab('storage'));
  await pg.waitForTimeout(600);

  // ── 얼마나 쓰고 있는지 ──────────────────────────────────────────
  const use = await pg.evaluate(() => (document.getElementById('cs-usage') || {}).textContent || '');
  ok(/89\.8 MB|GB|MB/.test(use), '얼마나 쓰고 있는지 보여 준다');
  ok(/채팅 사진·파일/.test(use), '어디에 쓰는지도 보여 준다');

  // ── 무엇이 자리를 차지하나 ──────────────────────────────────────
  const c = await cards(pg);
  console.log('     첫 장:', c[0] && c[0].txt);
  ok(c.length === 4, '올린 파일을 낱낱이 보여 준다');
  ok(/video\.mp4/.test(c[0].txt) && /86\.8 MB|MB/.test(c[0].txt), '이름과 크기를 적는다');
  ok(/2026\.10\.0?2/.test(c[0].txt), '언제 올렸는지 적는다');
  ok(/채팅 사진·파일/.test(c[0].txt), '어느 갈래인지 적는다');
  ok(c[1].img === true, '사진은 그림으로 보여 준다');
  ok(c[0].img === false, '영상·문서는 그림 대신 표시로 보여 준다');
  ok(/chat\/ch1\/video\.mp4/.test(c[0].href || ''), '눌러서 열어 볼 수 있다');

  // ── 지우기 전에 먼저 알려 주는가 ────────────────────────────────
  const warn = await pg.evaluate(() => document.getElementById('admin-content').textContent);
  ok(/되돌릴 수 없어요/.test(warn), '지우면 되돌릴 수 없다고 미리 적어 둔다');
  ok(/깨진 그림으로 남습니다/.test(warn), '채팅 사진을 지우면 어떻게 되는지도 적어 둔다');

  // ── 고르기 ──────────────────────────────────────────────────────
  ok(await pg.evaluate(() => getComputedStyle(document.getElementById('sf-del')).display) === 'none',
     '아무것도 안 골랐으면 지우기 단추가 없다');
  await pg.evaluate(() => { sfToggle(0); sfToggle(1); });
  await pg.waitForTimeout(200);
  const del = await pg.evaluate(() => (document.getElementById('sf-del') || {}).textContent || '');
  ok(/2개/.test(del), '몇 개를 골랐는지 적는다');
  ok(/MB/.test(del), '얼마나 비는지도 적는다 — ' + del.trim());

  // ── 지우기 ──────────────────────────────────────────────────────
  await pg.evaluate(() => sfDeletePicked());
  await pg.waitForTimeout(400);
  console.log('     물어본 말:', (asked || '').replace(/\n/g, ' / '));
  ok(/되돌릴 수 없습니다/.test(asked), '지우기 전에 한 번 더 묻는다');
  ok(/2개는 채팅에 올린 것이라/.test(asked), '채팅 것이 섞여 있으면 그것까지 말해 준다');
  const rm = await pg.evaluate(() => window.__rm);
  ok(rm.length === 1 && rm[0].b === 'messenger', '저장소에 지우라고 말한다');
  ok(rm[0].paths.join(',') === 'chat/ch1/video.mp4,chat/ch1/photo.jpg', '고른 것만 지운다');
  const left = await cards(pg);
  ok(left.length === 2 && !/video\.mp4/.test(left.map(x => x.txt).join(' ')), '지운 것은 목록에서 사라진다');

  // ── 규칙에 막혀 0개가 돌아올 때 ─────────────────────────────────
  //  오류가 아니라 **빈 답**이 온다. '지웠습니다' 라고 하면 안 된다.
  await seed(pg);
  await pg.evaluate(() => { window.__rmResult = () => ({ data: [], error: null }); });
  await pg.evaluate(() => switchAdminTab('storage'));
  await pg.waitForTimeout(500);
  await pg.evaluate(() => { sfToggle(0); });
  await pg.evaluate(() => sfDeletePicked());
  await pg.waitForTimeout(400);
  const toast = await pg.evaluate(() => document.body.textContent);
  ok(/하나도 안 지워졌어요/.test(toast), '안 지워졌으면 지워졌다고 하지 않는다');
  ok(/저장용량_파일목록_DB설치\.sql/.test(toast), '무엇을 돌려야 하는지 알려 준다');
  ok((await cards(pg)).length === 4, '안 지워졌으니 목록에도 그대로 있다');

  // ── 아직 설치 안 했을 때 ────────────────────────────────────────
  await pg.evaluate(() => {
    window.__rmResult = null;
    delete window.__DB['rpc:community_storage_files'];
    window.__err = { table:'rpc:community_storage_files', e:{ message:'Could not find the function public.community_storage_files', code:'PGRST202' } };
  });
  await pg.evaluate(() => switchAdminTab('storage'));
  await pg.waitForTimeout(500);
  ok(/저장용량_파일목록_DB설치\.sql/.test(await pg.evaluate(() => document.getElementById('sf-list').textContent)),
     '설치 전이면 무엇을 돌려야 하는지 알려 준다');

  await pg.close(); await b.close(); done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
