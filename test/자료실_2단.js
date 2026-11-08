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
    //  전체 공용 폴더는 종류마다 따로다
    window.__DB['app_settings'] = ss
      ? [{ key: 'drive_shared_folder_id_community', value: 'SHARED_ROOT' }]
      : [];
    window.__DB['communities'] = [{ id:'c1', name:'IM HQ', kind:'community' }];
    window.__fnResult = { 'drive-list': eval(ans) };
    driveScope = 'mine'; drivePath = []; driveSearch = '';
    driveSharedOn = null; driveMyKind = null; driveNeedsFolder = false;
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
      driveSharedOn = null; driveMyKind = null; driveScope = 'mine'; drivePath = []; driveNeedsFolder = false;
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
  ok(/같은 폴더 하나/.test(r.super_admin.txt) && /그룹/.test(r.super_admin.txt),
     '무슨 칸인지 — 같은 그룹끼리 같은 폴더를 본다고 설명해준다');
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
    out.box = !!el.querySelector('#shared-drive-community');
    out.kinds = [...el.querySelectorAll('[data-shared-kind]')].map(x => x.dataset.sharedKind);
    out.academyBox = !!el.querySelector('#shared-drive-academy');
    out.txt = el.innerText;
    //  폴더 주소를 통째로 붙여넣어도 ID 만 뽑는가
    document.getElementById('shared-drive-community').value =
      'https://drive.google.com/drive/folders/1AbC2dEfGhIjKlMnOpQrStUv?usp=sharing';
    window.__ins = [];
    await saveSharedDriveFolder('community');
    out.sent = JSON.stringify(window.__ins);
    out.on = driveSharedOn;
    //  아카데미 칸도 자기 열쇠로 가야 한다
    document.getElementById('shared-drive-academy').value = '1ACADEMYFOLDERID00';
    window.__ins = [];
    await saveSharedDriveFolder('academy');
    out.sentAcademy = JSON.stringify(window.__ins);
    //  총관리자가 아니면 아예 안 보낸다
    ME.community_role = 'community_admin';
    window.__ins = [];
    await saveSharedDriveFolder('community');
    out.sentByAdmin = JSON.stringify(window.__ins);
    return out;
  });
  ok(r.box, '총관리자에게 전체 공용 폴더 칸이 있다');
  ok(/종류마다 따로/.test(r.txt) && /서로 다른 자료실/.test(r.txt),
     '그룹마다 따로 쓴다고 적어 놓았다');
  ok(/공동체 설정/.test(r.txt) && /다른 칸/.test(r.txt),
     '공동체별 폴더와 다른 칸이라고 못 박아 놓았다 ← 여기가 헛갈리는 자리다');
  ok(/"value":"1AbC2dEfGhIjKlMnOpQrStUv"/.test(r.sent),
     '폴더 주소를 붙여넣어도 ID 만 뽑아 저장한다');
  ok(/"key":"drive_shared_folder_id_community"/.test(r.sent),
     '리뉴젠 공동체 그룹의 열쇠에 저장한다 ← 아카데미와 섞이지 않는다');
  ok(r.kinds.join(',') === 'community,academy', '칸이 그룹별로 두 개다 ← 이게 요청이었다');
  ok(/"key":"drive_shared_folder_id_academy"/.test(r.sentAcademy),
     '아카데미 칸은 아카데미 열쇠로 저장한다 ← 두 칸이 같은 자리에 쓰면 안 된다');
  ok(/"value":"1ACADEMYFOLDERID00"/.test(r.sentAcademy), '아카데미 칸의 값이 그대로 간다');
  ok(r.academyBox, '리뉴젠 아카데미 칸도 따로 있다');
  ok(r.sentByAdmin === '[]', '공동체 관리자는 아예 보내지 않는다');
  await pg.close();
}

// ── ⑥-2 앱이 **어느 열쇠를 보는가** ──────────────────────────
//  ⚠️ 처음엔 ⑦⑧ 에서 서버 답을 직접 흉내냈더니, 앱이 종류를 안 보게
//     되돌려도 시험이 통과했다. 앱이 실제로 고르는 열쇠를 잰다.
console.log('\n⑥-2 앱이 보는 열쇠');
{
  for (const [kind, koName] of [['community','리뉴젠 공동체'], ['academy','리뉴젠 아카데미']]) {
    const pg = await openApp(b, { as:'teacher' });
    const r = await pg.evaluate(async (k) => {
      //  **그 종류의 열쇠만** 넣어 둔다. 앱이 엉뚱한 열쇠를 보면 못 찾는다.
      window.__DB['communities'] = [{ id:'c1', name:'우리', kind:k }];
      window.__DB['app_settings'] = [{ key:'drive_shared_folder_id_' + k, value:'FOLDER_' + k }];
      driveSharedOn = null; driveMyKind = null;
      await driveLoadShared();
      return { on: driveSharedOn, kind: driveMyKind, key: sharedKeyFor(k) };
    }, kind);
    await pg.close();
    console.log(`       ${koName}: 열쇠 ${r.key} · 찾음 ${r.on}`);
    ok(r.key === 'drive_shared_folder_id_' + kind, `${koName} 은 자기 열쇠를 쓴다`);
    ok(r.kind === kind, `${koName} 의 종류를 바르게 읽는다`);
    ok(r.on === true,
       `${koName} 열쇠만 넣어 둬도 찾아낸다 ← 한 열쇠만 보면 여기서 걸린다`);
  }
  //  반대 — 다른 그룹 열쇠만 있으면 못 찾아야 한다
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    window.__DB['communities'] = [{ id:'c1', name:'리뉴젠스쿨', kind:'academy' }];
    window.__DB['app_settings'] = [{ key:'drive_shared_folder_id_community', value:'FOLDER_COMMUNITY' }];
    driveSharedOn = null; driveMyKind = null;
    await driveLoadShared();
    return { on: driveSharedOn };
  });
  await pg.close();
  ok(r.on === false,
     '아카데미 공동체는 공동체 그룹 폴더를 자기 것으로 삼지 않는다 ← 섞이면 안 된다');
}

// ── ⑦ 그룹마다 다른 자료실 ────────────────────────────────────
console.log('\n⑦ 그룹마다 다른 자료실');
{
  //  두 그룹에 서로 다른 폴더를 넣어 두고, 어느 공동체로 보느냐에 따라
  //  다른 폴더가 열리는지 본다.
  const ANS = `(body) => {
    const sc = body.scope === 'shared' ? 'shared' : 'mine';
    //  서버가 하는 일을 그대로 흉내낸다 — 보고 있는 공동체의 종류로 고른다
    const kind = window.__kind || 'community';
    if (sc === 'shared') {
      const key = 'drive_shared_folder_id_' + kind;
      const row = (window.__DB['app_settings'] || []).find(x => x.key === key);
      const v = row && row.value;
      if (!v) return { data: { error: '아직', needsFolder: true, scope:'shared', sharedKind: kind }, error: null };
      return { data: { v:5, scope:'shared', sharedKind: kind, rootId:v, folderId:v,
        breadcrumb:[{id:v,name:v}],
        files:[{ id:'f', name: kind + '전용파일.pdf', isFolder:false, mimeType:'application/pdf',
                 size:1, modifiedTime:'2026-01-01T00:00:00Z', viewUrl:'x', downloadUrl:'y' }] }, error: null };
    }
    return { data: { v:5, scope:'mine', rootId:'M', folderId:'M', communityName:'우리',
      breadcrumb:[{id:'M',name:'우리'}], files:[] }, error: null };
  }`;

  for (const [kind, koName, want] of [
    ['community', '리뉴젠 공동체',   'community전용파일.pdf'],
    ['academy',   '리뉴젠 아카데미', 'academy전용파일.pdf'],
  ]) {
    const pg = await openApp(b, { as:'teacher' });
    const r = await pg.evaluate(async ([ans, k]) => {
      window.__kind = k;
      window.__DB['communities'] = [{ id:'c1', name:'우리', kind: k }];
      window.__DB['app_settings'] = [
        { key:'drive_shared_folder_id_community', value:'FOLDER_COMMUNITY' },
        { key:'drive_shared_folder_id_academy',   value:'FOLDER_ACADEMY' },
      ];
      window.__fnResult = { 'drive-list': eval(ans) };
      driveScope='mine'; drivePath=[]; driveSearch='';
      driveSharedOn=null; driveMyKind=null; driveNeedsFolder=false;
      ME.community_role='super_admin';
      document.getElementById('drive-main') ||
        document.body.insertAdjacentHTML('beforeend', '<div id="drive-main"></div>');
      await initDrivePage();
      driveSwitchScope('shared');
      await new Promise(r2=>setTimeout(r2,400));
      const el = document.getElementById('drive-main');
      const call = (window.__fn||[]).filter(x=>x.name==='drive-list').pop();
      return { txt: el.innerText, scope: call && call.body.scope, kind: driveMyKind };
    }, [ANS, kind]);
    await pg.close();
    console.log(`       ${koName}: ${r.txt.split('\n').find(l=>/전용파일/.test(l)) || '(파일 없음)'}`);
    ok(r.kind === kind, `${koName} 공동체에서는 종류를 ${kind} 로 본다`);
    ok(r.txt.includes(want), `${koName} 그룹은 자기 그룹 자료실이 열린다`);
    ok(!r.txt.includes(kind === 'community' ? 'academy전용파일' : 'community전용파일'),
       `${koName} 그룹에 다른 그룹 자료실이 섞이지 않는다 ← 이게 핵심이다`);
    ok(/그룹/.test(r.txt), '지금 어느 그룹 자료실인지 화면에 적어준다');
  }
}

// ── ⑧ 한쪽만 비어 있을 때 ─────────────────────────────────────
console.log('\n⑧ 아카데미 그룹만 아직 안 정했을 때');
{
  const ANS = `(body) => {
    const kind = window.__kind || 'community';
    if (body.scope === 'shared') {
      const row = (window.__DB['app_settings']||[]).find(x => x.key === 'drive_shared_folder_id_' + kind);
      if (!row || !row.value) return { data:{ error:'아직', needsFolder:true, scope:'shared', sharedKind:kind }, error:null };
      return { data:{ v:5, scope:'shared', sharedKind:kind, rootId:row.value, folderId:row.value,
        breadcrumb:[{id:row.value,name:'공용'}], files:[] }, error:null };
    }
    return { data:{ v:5, scope:'mine', rootId:'M', folderId:'M', breadcrumb:[{id:'M',name:'우리'}], files:[] }, error:null };
  }`;
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (ans) => {
    window.__kind = 'academy';
    window.__DB['communities'] = [{ id:'c1', name:'리뉴젠스쿨', kind:'academy' }];
    //  공동체 그룹만 정해져 있다
    window.__DB['app_settings'] = [{ key:'drive_shared_folder_id_community', value:'FOLDER_COMMUNITY' }];
    window.__fnResult = { 'drive-list': eval(ans) };
    driveScope='mine'; drivePath=[]; driveSearch='';
    driveSharedOn=null; driveMyKind=null; driveNeedsFolder=false;
    ME.community_role='super_admin';
    document.getElementById('drive-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="drive-main"></div>');
    await initDrivePage();
    driveSwitchScope('shared');
    await new Promise(r2=>setTimeout(r2,400));
    return { txt: document.getElementById('drive-main').innerText };
  }, ANS);
  await pg.close();
  ok(/아직 없어요/.test(r.txt),
     '아카데미 그룹은 아직 없다고 알려준다 ← 공동체 그룹 폴더를 대신 보여주지 않는다');
  ok(/리뉴젠 아카데미/.test(r.txt), '어느 그룹 얘기인지 이름을 적어준다');
  ok(!/FOLDER_COMMUNITY/.test(r.txt), '다른 그룹 폴더로 되돌아가지 않는다');
}

await b.close();
done();
})();
