//  🏛️ 부총관리자도 공동체를 만들 수 있게
//
//    "부총관리자도 공동체를 만들수있는 권한을 줘"
//
//  다만 **자기 묶음(kind) 안에서만** 입니다.
//   부총관리자가 보는 범위는 공동체의 kind 로 갈립니다(리뉴젠 공동체 /
//   리뉴젠 아카데미 / 해외 그룹). 다른 묶음으로 만들면 **만든 본인이 그
//   공동체를 못 봅니다** — 만들자마자 사라지는 셈이라, 열어 두는 것이
//   오히려 덫입니다.
//
//  운영 DB 에서 사람 흉내로 미리 재 보았습니다(글은 전부 되돌렸습니다):
//   ① 자기 묶음으로 만들기 ✅  ② 해외 묶음으로 만들기 ✅막힘
//   ③ 지우기 0줄 ✅           ④ 공동체 관리자는 ✅막힘
//   ⑤ 총관리자는 어느 묶음이든 ✅ (전과 같음)
//
//  ★ 여기서 재는 것 — 화면을 그려서 읽습니다
//   ① 🏛️ 공동체 탭이 부총관리자에게 보인다 (일반 관리자에겐 안 보인다)
//   ② 종류 고르개에 **자기 묶음 하나만** 뜨고 잠겨 있다
//   ③ 목록에 자기 묶음만 보인다 (다른 묶음은 눌러도 못 하는 칸이다)
//   ④ 지우기 단추가 없다 · 수정은 자기 공동체에만
//   ⑤ 전체 공용 자료실 폴더(총관리자 것)는 안 보인다
//   ⑥ 만들 때 종류를 자기 묶음으로 못 박아 보낸다
//   ⑦ 총관리자는 전과 똑같다
const { launch, openApp, ok, done } = require('./_harness');

const COMMS = [
  { id:'c1',  name:'프로토스',   kind:'community', created_at:'2026-01-01', color:'#1d3a5f' },
  { id:'c2',  name:'어웨이크닝', kind:'community', created_at:'2026-01-02', color:'#1d3a5f' },
  { id:'a1',  name:'리뉴젠 아카데미', kind:'academy', created_at:'2026-01-03', color:'#1d3a5f' },
  { id:'o1',  name:'IM USA',     kind:'overseas',  created_at:'2026-01-04', color:'#1d3a5f' },
];

async function openAdmin(b, role) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((r) => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1'; ME.community_role = r;
    ME.email = 'nobody@example.com';
    window.__DB.communities = [
      { id:'c1',  name:'프로토스',   kind:'community', created_at:'2026-01-01T00:00:00Z', color:'#1d3a5f' },
      { id:'c2',  name:'어웨이크닝', kind:'community', created_at:'2026-01-02T00:00:00Z', color:'#1d3a5f' },
      { id:'a1',  name:'리뉴젠 아카데미', kind:'academy', created_at:'2026-01-03T00:00:00Z', color:'#1d3a5f' },
      { id:'o1',  name:'IM USA',     kind:'overseas',  created_at:'2026-01-04T00:00:00Z', color:'#1d3a5f' },
    ];
    window.__DB.app_settings = [];
    window.__DB.members = [];
    document.getElementById('admin-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
  }, role);
  return pg;
}

const READ = async (pg) => pg.evaluate(() => {
  const box = document.getElementById('admin-content');
  const kindSel = document.getElementById('new-comm-kind');
  return {
    txt: box.innerText,
    kinds: kindSel ? [...kindSel.options].map(o => o.value) : null,
    kindLocked: kindSel ? kindSel.disabled : null,
    del: [...box.querySelectorAll('button')].filter(x => /deleteCommunity/.test(x.getAttribute('onclick')||'')).length,
    edit: [...box.querySelectorAll('button')].map(x => x.getAttribute('onclick')||'')
            .filter(x => /editCommunity/.test(x)),
    shared: !!document.getElementById('shared-drive-community'),
    makeBtn: [...box.querySelectorAll('button')].some(x => /createCommunity/.test(x.getAttribute('onclick')||'')),
  };
});

(async () => {
const b = await launch();

// ── ① 탭이 보이나 ───────────────────────────────────────────────
console.log('\n① 🏛️ 공동체 탭 — 누구에게 보이나');
{
  for (const [role, want, 말] of [
    ['vice_admin', true,  '부총관리자에게 보인다'],
    ['community_admin', false, '일반 공동체 관리자에게는 안 보인다'],
    ['super_admin', true, '총관리자에게 보인다 (전과 같음)'],
  ]) {
    const pg = await openAdmin(b, role);
    const seen = await pg.evaluate(() => {
      document.getElementById('adm-tab-communities').style.display = 'none';
      showAdminTabsFor();
      return document.getElementById('adm-tab-communities').style.display !== 'none';
    });
    ok(seen === want, 말, '보임=' + seen);
    await pg.close();
  }
}

// ── ②③④⑤ 부총관리자 화면 ──────────────────────────────────────
console.log('\n②③④⑤ 부총관리자가 보는 🏛️ 공동체 화면');
{
  const pg = await openAdmin(b, 'vice_admin');
  await pg.evaluate(() => renderAdminCommunities());
  await pg.waitForTimeout(200);
  const r = await READ(pg);
  ok(r.makeBtn, '「새 공동체 만들기」 단추가 있다');
  ok(r.kinds && r.kinds.length === 1 && r.kinds[0] === 'community',
     '종류 고르개에 자기 묶음 하나만 뜬다', JSON.stringify(r.kinds));
  ok(r.kindLocked === true, '그 고르개는 잠겨 있다 — 다른 묶음을 고를 수 없다');
  ok(/자기 묶음 안에서만/.test(r.txt), '왜 하나뿐인지 알려 준다');
  ok(/프로토스/.test(r.txt) && /어웨이크닝/.test(r.txt), '같은 묶음 공동체가 보인다');
  ok(!/리뉴젠 아카데미/.test(r.txt) && !/IM USA/.test(r.txt),
     '다른 묶음은 안 보인다 — 눌러도 못 하는 칸을 만들지 않는다');
  ok(r.del === 0, '지우기 단추가 하나도 없다', r.del + '개');
  ok(r.edit.length === 1 && /'c1'/.test(r.edit[0]),
     '수정은 자기 공동체에만 붙는다', JSON.stringify(r.edit));
  ok(r.shared === false, '전체 공용 자료실 폴더(총관리자 것)는 안 보인다');
  await pg.close();
}

// ── ⑥ 만들 때 종류를 못 박아 보낸다 ─────────────────────────────
console.log('\n⑥ 만들 때 — 종류를 자기 묶음으로 못 박아 보낸다');
{
  const pg = await openAdmin(b, 'vice_admin');
  await pg.evaluate(() => renderAdminCommunities());
  await pg.waitForTimeout(200);
  const r = await pg.evaluate(async () => {
    document.getElementById('new-comm-name').value = '새 공동체';
    //  화면이 틀어져 다른 묶음이 들어가 있어도 자기 묶음으로 보내야 한다
    const sel = document.getElementById('new-comm-kind');
    sel.innerHTML = '<option value="overseas">해외</option>';
    sel.value = 'overseas'; sel.disabled = false;
    await createCommunity();
    await new Promise(r => setTimeout(r, 150));
    const ins = (window.__ins || []).filter(x => x.t === 'communities').pop();
    return { sent: ins ? ins.rows[0] : null };
  });
  ok(r.sent, '만들기를 보냈다');
  ok(r.sent && r.sent.kind === 'community',
     '화면이 해외로 틀어져 있어도 자기 묶음(community)으로 보낸다', r.sent && r.sent.kind);
  ok(r.sent && r.sent.name === '새 공동체', '이름은 적은 그대로', r.sent && r.sent.name);
  await pg.close();
}

// ── ⑦ 총관리자는 전과 같다 ──────────────────────────────────────
console.log('\n⑦ 총관리자 — 전과 똑같아야 한다');
{
  const pg = await openAdmin(b, 'super_admin');
  await pg.evaluate(() => renderAdminCommunities());
  await pg.waitForTimeout(200);
  const r = await READ(pg);
  ok(r.kinds && r.kinds.length >= 3, '종류를 전부 고를 수 있다', JSON.stringify(r.kinds));
  ok(r.kindLocked === false, '고르개가 잠겨 있지 않다');
  ok(/프로토스/.test(r.txt) && /리뉴젠 아카데미/.test(r.txt) && /IM USA/.test(r.txt),
     '모든 묶음이 보인다');
  ok(r.del >= 3, '지우기 단추가 있다', r.del + '개');
  ok(r.edit.length >= 4, '수정이 모든 공동체에 붙는다', r.edit.length + '개');
  ok(r.shared === true, '전체 공용 자료실 폴더가 보인다');
  await pg.close();
}

done(b);
})();
