//  📷 관리자가 아이들 사진 올리기 (개선창 · 김환경 간사 · 어웨이크닝)
//
//    "아이들 사진을 업로드 했는데 이름 옆에 사진이 보이면 좋을것 같습니다.
//     현재는 이모티콘이 보이네요."
//
//  재 보니 어웨이크닝 학생 6명 전부 photo_url 이 비어 있었습니다.
//  사진 올리기가 `.eq('id', ME.id)` — **자기 것만** 이었고, 관리자가
//  아이 사진을 올릴 자리가 아예 없었습니다. 서버는 공동체 관리자에게
//  열려 있었고(운영 DB 에서 재서 확인), 막힌 건 화면뿐이었습니다.
const { launch, openApp, ok, done } = require('./_harness');

const SEED = [
  { id:'me',  name:'김선생',  community_id:'c1', community_role:'community_admin', status:'approved' },
  { id:'s1',  name:'사진없는학생', community_id:'c1', community_role:'student', status:'approved' },
  { id:'s2',  name:'사진있는학생', community_id:'c1', community_role:'student', status:'approved',
              photo_url:'https://example.com/a.jpg' },
];

async function openAdmin(b, role) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(async (d) => {
    window.__DB.members = d.SEED;
    window.__DB.student_groups = [];
    ME.community_role = d.role; ME.community_id = 'c1';
    document.getElementById('admin-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
    await renderAdminMembers();
  }, { SEED, role });
  return pg;
}
const READ = `() => {
  const el = document.getElementById('admin-content');
  const av = id => el.querySelector('[data-adm-av="' + id + '"]');
  return {
    avs: [...el.querySelectorAll('[data-adm-av]')].map(x => x.dataset.admAv),
    clickable: [...el.querySelectorAll('[data-adm-av]')]
                 .filter(x => (x.getAttribute('onclick')||'').includes('admPickPhoto'))
                 .map(x => x.dataset.admAv),
    cam: [...el.querySelectorAll('[data-adm-av]')]
           .filter(x => x.innerText.includes('\\u{1F4F7}')).map(x => x.dataset.admAv),
    rm: [...el.querySelectorAll('[data-adm-rmphoto]')].map(x => x.dataset.admRmphoto),
    s1HasPhoto: /url\\(/.test((av('s1')||{}).getAttribute ? av('s1').getAttribute('style') : ''),
    s2HasPhoto: /url\\(/.test((av('s2')||{}).getAttribute ? av('s2').getAttribute('style') : ''),
  };
}`;

(async () => {
const b = await launch();

// ── ① 누가 올릴 수 있나 ──────────────────────────────────────
console.log('\n① 누가 올릴 수 있나');
{
  for (const [role, can, label] of [
    ['community_admin', true,  '공동체 관리자'],
    ['super_admin',     true,  '총관리자'],
    ['teacher',         false, '교사'],
    ['staff',           false, '간사'],
  ]) {
    const pg = await openAdmin(b, role);
    const r = await pg.evaluate(eval(READ));
    await pg.close();
    if (can) {
      ok(r.clickable.length === r.avs.length && r.avs.length > 0,
         `${label} — 모든 멤버 사진을 누를 수 있다 (${r.avs.length}명)`);
      ok(r.cam.length === r.avs.length, `${label} — 📷 표가 붙는다`);
    } else {
      ok(r.clickable.length === 0, `${label} — 누를 수 없다 ← 서버도 막는다`);
      ok(r.cam.length === 0, `${label} — 📷 표가 안 붙는다 (눌러서 실패하게 두지 않는다)`);
    }
  }
}

// ── ② 사진이 있을 때만 '내리기' ──────────────────────────────
console.log('\n② 사진 내리기 단추');
{
  const pg = await openAdmin(b, 'community_admin');
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.s2HasPhoto, '사진이 있는 학생은 그림으로 나온다');
  ok(!r.s1HasPhoto, '사진이 없는 학생은 글자 아이콘이다');
  ok(r.rm.join(',') === 's2', '사진이 있는 사람에게만 내리기 단추가 있다');
}

// ── ③ 실제로 저장되나 ────────────────────────────────────────
console.log('\n③ 저장');
{
  const pg = await openAdmin(b, 'community_admin');
  const r = await pg.evaluate(async () => {
    const out = {};
    //  저장통 올리기를 가짜로 바꾼다 (시험은 그물을 안 탄다)
    sb.storage = { from: () => ({
      upload: async (path) => { window.__upPath = path; return { error: null }; },
      getPublicUrl: () => ({ data: { publicUrl: 'https://example.com/new.jpg' } }),
    }) };
    //  자르기 창도 건너뛴다
    window.pfpAdjust = async () => new Blob(['x'], { type: 'image/jpeg' });
    _admPhotoFor = { id:'s1', name:'사진없는학생' };
    window.__upd = [];
    await admUploadPhoto({ files: [new File(['x'], 'a.jpg', { type:'image/jpeg' })], value: '' });
    out.path = window.__upPath;
    out.sent = JSON.stringify(window.__upd);
    out.inList = (admMembers.find(x => x.id === 's1') || {}).photo_url;
    return out;
  });
  await pg.close();
  ok(/^avatars\/s1\//.test(r.path || ''), '그 학생 폴더에 올린다 (' + r.path + ')');
  ok(/\.jpg$/.test(r.path || ''), '이름을 새로 지어 올린다 (덮어쓰면 옛 사진이 남는다)');
  ok(/"photo_url":"https:\/\/example\.com\/new\.jpg"/.test(r.sent), '사진 주소를 저장한다');
  ok(/"id":"s1"/.test(r.sent) || /s1/.test(r.sent), '그 학생에게 저장한다 ← 내 것이 아니다');
  ok(r.inList === 'https://example.com/new.jpg', '목록에도 바로 반영된다');
}

// ── ④ 규칙에 막히면 조용히 넘어가지 않는다 ───────────────────
console.log('\n④ 막혔을 때');
{
  const pg = await openAdmin(b, 'community_admin');
  const r = await pg.evaluate(async () => {
    sb.storage = { from: () => ({
      upload: async () => ({ error: null }),
      getPublicUrl: () => ({ data: { publicUrl: 'https://example.com/n.jpg' } }),
    }) };
    window.pfpAdjust = async () => new Blob(['x'], { type: 'image/jpeg' });
    //  0줄 고침 — 규칙에 막힌 모양
    const realFrom = sb.from;
    sb.from = (tbl) => {
      if (tbl !== 'members') return realFrom(tbl);
      const q = realFrom(tbl);
      const realThen = q.then.bind(q);
      q.then = (res, rej) => realThen(() => res({ data: [], error: null }), rej);
      return q;
    };
    let said = '';
    const realToast = window.showUploadToast;
    window.showUploadToast = (m) => { said += m + '|'; };
    _admPhotoFor = { id:'s1', name:'학생' };
    await admUploadPhoto({ files: [new File(['x'], 'a.jpg', { type:'image/jpeg' })], value: '' });
    window.showUploadToast = realToast; sb.from = realFrom;
    return { said };
  });
  await pg.close();
  ok(/권한이 없어요/.test(r.said),
     '0줄이 돌아오면 권한이 없다고 알려준다 ← 조용히 성공했다고 하면 안 된다');
  ok(!/올렸어요/.test(r.said), "'올렸어요' 라고 거짓말하지 않는다");
}

await b.close();
done();
})();
