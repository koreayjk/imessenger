//  📁🌐 자료실 2단 — 🏠 우리 공동체 / 🌐 전체 공용
//
//  · 우리 공동체 폴더  : communities.drive_root_folder_id (공동체마다 다름)
//  · 전체 공용 폴더    : app_settings.drive_shared_folder_id (하나, 총관리자)
//
//  칸을 옮기면 경로와 검색을 **반드시** 비워야 합니다. 안 비우면 저쪽
//  폴더 id 를 들고 이쪽에서 열려고 해서 '경로를 확인하지 못했습니다' 가 뜹니다.
const { launch, openApp, ok, done } = require('./_harness');

//  drive-list 가 돌려줄 답 — scope 에 따라 다른 폴더를 돌려주는 흉내
const ANSWER = `(body) => {
  const sc = body.scope === 'shared' ? 'shared' : 'mine';
  if (sc === 'shared' && !window.__sharedSet) {
    return { data: { error: '전체 공용 자료실 폴더가 아직 지정되지 않았습니다.', needsFolder: true, scope: 'shared' }, error: null };
  }
  return { data: {
    v: 4, scope: sc,
    rootId: sc === 'shared' ? 'SHARED_ROOT' : 'MINE_ROOT',
    folderId: sc === 'shared' ? 'SHARED_ROOT' : 'MINE_ROOT',
    communityName: sc === 'shared' ? '' : 'IM HQ',
    breadcrumb: [{ id: sc === 'shared' ? 'SHARED_ROOT' : 'MINE_ROOT', name: sc === 'shared' ? '전체 공용' : '우리 자료실' }],
    files: [{ id: 'f_' + sc, name: (sc === 'shared' ? '공용파일.pdf' : '우리파일.pdf'), isFolder: false, mimeType: 'application/pdf', size: 100, modifiedTime: '2026-01-01T00:00:00Z', viewUrl: 'x', downloadUrl: 'y' }],
  }, error: null };
}`;

async function setup(b, as, sharedSet) {
  const pg = await openApp(b, { as });
  await pg.evaluate(([ans, ss]) => {
    window.__sharedSet = ss;
    window.__DB['app_settings'] = ss
      ? [{ key: 'drive_shared_folder_id', value: 'SHARED_ROOT' }]
      : [];
    window.__fnResult = { 'drive-list': eval(ans) };
    driveScope = 'mine'; drivePath = []; driveSearch = '';
    driveSharedOn = null; driveNeedsFolder = false;
    document.getElementById('drive-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="drive-main"></div>');
  }, [ANSWER, sharedSet]);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 탭이 보이나 ────────────────────────────────────────────
console.log('\n① 탭이 보이나');
{
  const pg = await setup(b, 'teacher', true);
  const r = await pg.evaluate(async () => {
    ME.community_role = 'teacher';
    await initDrivePage();
    const el = document.getElementById('drive-main');
    return {
      tabs: [...el.querySelectorAll('[data-drive-tab]')].map(x => x.dataset.driveTab),
      txt: el.innerText,
    };
  });
  ok(r.tabs.join(',') === 'mine,shared', '칸 두 개가 나온다 — 우리 공동체 · 전체 공용');
  ok(/우리 공동체/.test(r.txt) && /전체 공용/.test(r.txt), '이름이 또박또박 적혀 있다');
  ok(/우리파일\.pdf/.test(r.txt), '처음에는 우리 공동체 자료실이 열린다');
  await pg.close();
}

// ── ② 전체 공용 폴더가 없으면 ───────────────────────────────
console.log('\n② 전체 공용 폴더가 아직 없을 때');
{
  const pg = await setup(b, 'teacher', false);
  const r = await pg.evaluate(async () => {
    const out = {};
    ME.community_role = 'teacher';
    await initDrivePage();
    out.teacher = [...document.querySelectorAll('[data-drive-tab]')].map(x => x.dataset.driveTab);
    //  총관리자는 정하러 갈 수 있어야 하니 칸이 보인다
    ME.community_role = 'super_admin';
    driveSharedOn = null; driveScope = 'mine'; drivePath = [];
    await initDrivePage();
    const el = document.getElementById('drive-main');
    out.superTabs = [...el.querySelectorAll('[data-drive-tab]')].map(x => x.dataset.driveTab);
    out.superHint = el.innerText;
    return out;
  });
  ok(r.teacher.length === 0,
     '폴더가 없으면 교사에게는 칸을 아예 안 보여준다 ← 들어가도 빈 칸뿐이다');
  ok(r.superTabs.join(',') === 'mine,shared', '총관리자에게는 보인다 (정하러 가야 하니까)');
  ok(/관리자/.test(r.superHint) && /공동체/.test(r.superHint),
     '어디서 정하는지 알려준다');
  await pg.close();
}

// ── ③ 칸을 옮기면 scope 가 가고, 경로가 비워진다 ─────────────
console.log('\n③ 칸 옮기기');
{
  const pg = await setup(b, 'teacher', true);
  const r = await pg.evaluate(async () => {
    ME.community_role = 'teacher';
    await initDrivePage();
    //  폴더 하나 들어가고 검색어도 넣어 둔다
    drivePath = ['SOME_SUBFOLDER']; driveSearch = '찾는중';
    window.__fn = [];
    driveSwitchScope('shared');
    await new Promise(r2 => setTimeout(r2, 400));
    const el = document.getElementById('drive-main');
    return {
      sent: window.__fn.map(x => ({ n: x.name, scope: x.body && x.body.scope, path: (x.body && x.body.path) || [], q: x.body && x.body.search })),
      scope: driveScope, path: drivePath, search: driveSearch,
      txt: el.innerText,
      on: [...el.querySelectorAll('[data-drive-tab]')].map(x => x.dataset.driveTab + ':' + (x.style.background.includes('29, 58, 95') || x.style.background.includes('#1d3a5f') ? 'ON' : 'off')),
    };
  });
  const call = r.sent.find(x => x.n === 'drive-list');
  ok(!!call && call.scope === 'shared', "전체 공용으로 옮기면 scope:'shared' 를 보낸다");
  ok(call && call.path.length === 0,
     '옮길 때 폴더 경로를 비운다 ← 저쪽 폴더 id 로 이쪽을 열면 오류가 난다');
  ok(call && !call.q, '검색어도 비운다');
  ok(r.search === '', '검색칸이 비어 있다');
  ok(/공용파일\.pdf/.test(r.txt), '전체 공용 자료실 내용이 나온다');
  ok(!/우리파일\.pdf/.test(r.txt), '우리 공동체 파일은 더 안 보인다');
  ok(r.on.join(',') === 'mine:off,shared:ON', '지금 보고 있는 칸에 표시가 된다');
  await pg.close();
}

// ── ④ 돌아오기 ───────────────────────────────────────────────
console.log('\n④ 우리 공동체로 돌아오기');
{
  const pg = await setup(b, 'teacher', true);
  const r = await pg.evaluate(async () => {
    ME.community_role = 'teacher';
    await initDrivePage();
    driveSwitchScope('shared');
    await new Promise(r2 => setTimeout(r2, 400));
    window.__fn = [];
    driveSwitchScope('mine');
    await new Promise(r2 => setTimeout(r2, 400));
    const el = document.getElementById('drive-main');
    const call = window.__fn.find(x => x.name === 'drive-list');
    return { scope: call && call.body.scope, txt: el.innerText };
  });
  ok(r.scope === 'mine', "돌아오면 scope:'mine' 을 보낸다");
  ok(/우리파일\.pdf/.test(r.txt), '우리 공동체 자료실이 다시 나온다');
  await pg.close();
}

// ── ⑤ 전체 공용 칸이 비었을 때 안내 ──────────────────────────
console.log('\n⑤ 전체 공용이 비었을 때 안내');
{
  const pg = await setup(b, 'teacher', false);
  const r = await pg.evaluate(async () => {
    const out = {};
    for (const role of ['super_admin','teacher']) {
      ME.community_role = role;
      driveSharedOn = null; driveScope = 'mine'; drivePath = []; driveNeedsFolder = false;
      await initDrivePage();
      driveSwitchScope('shared');
      await new Promise(r2 => setTimeout(r2, 400));
      const el = document.getElementById('drive-main');
      out[role] = { txt: el.innerText, btn: !!el.querySelector('[onclick*="setMode"]') };
    }
    return out;
  });
  ok(/전체 공용 자료실 폴더가 아직 없어요/.test(r.super_admin.txt),
     '전체 공용 칸이 비었다고 알려준다 (공동체 폴더 안내와 다른 글)');
  ok(/모든 공동체가 같은 폴더 하나/.test(r.super_admin.txt),
     '무슨 칸인지 설명해준다');
  ok(r.super_admin.btn, '총관리자에게는 정하러 가는 단추가 있다');
  ok(!r.teacher.btn && /총관리자에게/.test(r.teacher.txt),
     '교사에게는 단추 대신 총관리자에게 부탁하라고 적어준다');
  await pg.close();
}

// ── ⑥ 총관리자만 전체 공용 폴더를 정한다 ─────────────────────
console.log('\n⑥ 전체 공용 폴더 정하기');
{
  const pg = await setup(b, 'teacher', false);
  const r = await pg.evaluate(async () => {
    window.__DB.communities = [{ id:'c1', name:'IM HQ', kind:'community', created_at:'2026-01-01' }];
    window.__DB.members = [];
    document.getElementById('admin-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
    const out = {};
    ME.community_role = 'super_admin';
    await renderAdminCommunities();
    const el = document.getElementById('admin-content');
    out.box = !!el.querySelector('#shared-drive');
    out.txt = el.innerText;
    //  폴더 주소를 통째로 붙여넣어도 ID 만 뽑는가
    document.getElementById('shared-drive').value =
      'https://drive.google.com/drive/folders/1AbC2dEfGhIjKlMnOpQrStUv?usp=sharing';
    window.__ins = [];
    await saveSharedDriveFolder();
    out.sent = JSON.stringify(window.__ins);
    out.on = driveSharedOn;
    //  총관리자가 아니면 아예 안 보낸다
    ME.community_role = 'community_admin';
    window.__ins = [];
    await saveSharedDriveFolder();
    out.sentByAdmin = JSON.stringify(window.__ins);
    return out;
  });
  ok(r.box, '총관리자에게 전체 공용 폴더 칸이 있다');
  ok(/모든 공동체가 .*같은 폴더 하나/.test(r.txt.replace(/\n/g,' ')),
     '무슨 칸인지 적어 놓았다');
  ok(/공동체 설정/.test(r.txt) && /다른 칸/.test(r.txt),
     '공동체별 폴더와 다른 칸이라고 못 박아 놓았다 ← 여기가 헛갈리는 자리다');
  ok(/"value":"1AbC2dEfGhIjKlMnOpQrStUv"/.test(r.sent),
     '폴더 주소를 붙여넣어도 ID 만 뽑아 저장한다');
  ok(/"key":"drive_shared_folder_id"/.test(r.sent), '앱 전체 설정 한 자리에 저장한다');
  ok(r.on === true, '저장하면 자료실 칸이 바로 보이게 된다');
  ok(r.sentByAdmin === '[]', '공동체 관리자는 아예 보내지 않는다');
  await pg.close();
}

await b.close();
done();
})();
