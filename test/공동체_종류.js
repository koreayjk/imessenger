//  🏛️🎓🌏 공동체 종류 — 리뉴젠 공동체 / 리뉴젠 아카데미 / 해외 그룹
//
//  공동체가 20곳까지 늘었습니다. 갈래로 묶어서 보여 줍니다.
//  · 종류는 communities.kind — 'community' | 'academy' | 'overseas'
//  · 칸이 없는 옛 DB 에서도, 모르는 값이 들어와도 '리뉴젠 공동체'로 봅니다
//  · 종류는 **총관리자만** 바꿉니다 (서버에서도 막아 뒀습니다)
//  · 한 종류만 쓰면 묶음이 1개라 화면은 묶기 전과 똑같습니다
//
//  ⚠️ 갈래를 늘릴 때 'academy 냐 아니냐' 로 갈라 둔 자리가 남아 있으면,
//     새 갈래가 조용히 리뉴젠 공동체로 삼켜집니다. 자료실에서는 그게
//     **남의 그룹 자료실이 보이는** 사고가 됩니다. 그래서 종류를 늘려도
//     COMM_KINDS 만 보고 따라오는지를 잽니다.
const { launch, openApp, ok, done } = require('./_harness');

const COMMS = [
  { id:'c1', name:'IM HQ',    kind:'community', color:'#1d3a5f' },
  { id:'c2', name:'IM USA',   kind:'overseas',  color:'#2a7a5a' },
  { id:'c3', name:'리뉴젠스쿨', kind:'academy',  color:'#7B6BA0' },
  { id:'c4', name:'종류없음',   color:'#B05865' },          // ← 옛 DB (kind 칸 없음)
  { id:'c5', name:'엉뚱한값',   kind:'zzz',      color:'#8a4a22' }, // ← 모르는 값
];

(async () => {
const b = await launch();

// ── ① 종류 읽기 ──────────────────────────────────────────────
console.log('\n① 종류 읽기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((C) => ({
    kinds: C.map(c => commKind(c)),
    labels: COMM_KINDS.map(k => k.ko),
    groups: groupByCommKind(C).map(g => ({ v: g.kind.v, names: g.items.map(x => x.name) })),
    oneKind: groupByCommKind(C.filter(c => commKind(c) === 'community')).length,
    empty: groupByCommKind([]).length,
  }), COMMS);

  ok(r.kinds.join(',') === 'community,overseas,academy,community,community',
     '종류를 바르게 읽는다 (칸이 없거나 모르는 값이면 리뉴젠 공동체)');
  ok(r.labels.join(' · ') === '리뉴젠 공동체 · 리뉴젠 아카데미 · 해외 그룹',
     '종류가 1번 리뉴젠 공동체 · 2번 리뉴젠 아카데미 · 3번 해외 그룹 이다');
  //  ⚠️ 되돌려 보니 여기서 시험이 터져서 ②③④⑤ 를 아예 재지 못했다.
  //     터지지 않게 기본값을 두고, 뒷 묶음까지 다 재게 한다.
  const g0 = r.groups[0] || { v:'', names:[] }, g1 = r.groups[1] || { v:'', names:[] },
        g2 = r.groups[2] || { v:'', names:[] };
  ok(r.groups.length === 3, '세 갈래로 묶인다');
  ok(g0.v === 'community' && g0.names.length === 3,
     '리뉴젠 공동체가 먼저 오고 3곳이 들어간다 (칸 없는 것·모르는 값 포함)');
  ok(g1.v === 'academy' && g1.names[0] === '리뉴젠스쿨',
     '리뉴젠 아카데미가 그다음이고 리뉴젠스쿨이 들어간다');
  ok(g2.v === 'overseas' && g2.names[0] === 'IM USA',
     '해외 그룹이 끝에 오고 IM USA 가 들어간다 ← 공동체로 삼켜지지 않는다');
  ok(r.oneKind === 1, '한 종류만 있으면 묶음도 1개다 (화면이 전과 같아진다)');
  ok(r.empty === 0, '빈 목록은 묶음이 없다');
  await pg.close();
}

// ── ② 공동체 전환 창 ─────────────────────────────────────────
console.log('\n② 🏛️ 공동체 전환 창');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (C) => {
    ME.community_role = 'super_admin';
    window.__DB.communities = C;
    const read = () => {
      const ov = document.getElementById('community-switcher-overlay');
      const heads = ov ? [...ov.querySelectorAll('[data-comm-kind-head]')].map(x => x.dataset.commKindHead) : [];
      const txt = ov ? ov.innerText : '';
      ov && ov.remove();
      return { heads, txt };
    };
    await showCommunitySwitcher();
    const two = read();
    //  한 종류만 있을 때
    window.__DB.communities = C.filter(c => commKind(c) === 'community');
    await showCommunitySwitcher();
    const one = read();
    return { two, one };
  }, COMMS);

  ok(r.two.heads.join(',') === 'community,academy,overseas',
     '종류가 다 있으면 머리글이 순서대로 뜬다');
  ok(/리뉴젠 아카데미/.test(r.two.txt) && /리뉴젠스쿨/.test(r.two.txt),
     '아카데미 머리글과 그 아래 공동체가 보인다');
  ok(/해외 그룹/.test(r.two.txt), '해외 그룹 머리글도 보인다');
  ok(/IM HQ/.test(r.two.txt) && /IM USA/.test(r.two.txt), '공동체 쪽도 그대로 보인다');
  ok(r.one.heads.length === 0,
     '한 종류만 있으면 머리글을 붙이지 않는다 ← 괜히 어수선해지지 않게');
  ok(/IM HQ/.test(r.one.txt), '그래도 목록은 나온다');
  await pg.close();
}

// ── ③ 로그인 직후 고르기 화면 ─────────────────────────────────
console.log('\n③ 로그인 직후 고르기 화면');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((C) => {
    showCommunitySelect(C);
    const el = document.getElementById('community-list');
    const txt = el.innerText;
    const hd = [...el.querySelectorAll('[data-comm-kind-head]')];
    //  머리글이 한 줄을 통째로 쓰는가 (그리드가 깨지지 않게)
    const full = hd.filter(x => /1 ?\/ ?-1/.test(x.getAttribute('style') || '')).length;
    document.getElementById('community-select-screen').style.display = 'none';
    return { txt, heads: hd.map(x => x.dataset.commKindHead), full,
             cards: el.querySelectorAll('[onclick^="enterCommunity"]').length };
  }, COMMS);

  ok(r.heads.join(',') === 'community,academy,overseas', '여기도 세 갈래로 보인다');
  ok(/리뉴젠 아카데미/.test(r.txt) && /해외 그룹/.test(r.txt), '머리글 글씨도 제대로 나온다');
  ok(r.cards === 5, '공동체 5곳이 다 나온다 (묶어도 빠지지 않는다)');
  ok(r.full === 3, '머리글이 한 줄을 통째로 쓴다 (칸이 밀리지 않게)');
  await pg.close();
}

// ── ④ 관리자 ▸ 🏛️ 공동체 목록 ────────────────────────────────
console.log('\n④ 관리자 ▸ 공동체 목록');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (C) => {
    ME.community_role = 'super_admin';
    window.__DB.communities = C;
    window.__DB.members = [];
    document.getElementById('admin-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
    await renderAdminCommunities();
    const el = document.getElementById('admin-content');
    return {
      txt: el.innerText,
      heads: [...el.querySelectorAll('[data-comm-kind-head]')].map(x => x.dataset.commKindHead),
      cards: el.querySelectorAll('[onclick^="viewCommunityMembers"]').length,
      kindSel: !!el.querySelector('#new-comm-kind'),
      kindOpts: [...el.querySelectorAll('#new-comm-kind option')].map(o => o.value),
    };
  }, COMMS);

  //  ⚠️ 글자만 보면 안 된다 — '리뉴젠 아카데미' 가 새 공동체 만들기의
  //     종류 고르개 <option> 에도 있어서, 되돌려도 통과해 버렸다.
  ok(r.heads.join(',') === 'community,academy,overseas', '목록이 세 갈래로 나뉜다');
  ok(r.cards === 5, '5곳이 다 나온다 (묶는 바람에 빠진 곳이 없다)');
  ok(r.kindSel, '새 공동체 만들 때 종류를 고를 수 있다');
  ok(r.kindOpts.join(',') === 'community,academy,overseas', '고를 수 있는 종류가 셋이다');
  await pg.close();
}

// ── ⑤ 종류는 총관리자만 바꾼다 ────────────────────────────────
console.log('\n⑤ 종류는 총관리자만');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    document.getElementById('admin-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="admin-content"></div>');
    const out = {};
    for (const role of ['super_admin', 'community_admin']) {
      ME.community_role = role;
      editCommunity('c3', '리뉴젠스쿨', '', '#7B6BA0', 'academy');
      const el = document.getElementById('admin-content');
      out[role] = { sel: !!el.querySelector('#edit-comm-kind'), txt: el.innerText };
    }
    //  공동체 관리자가 저장하면 kind 를 아예 보내지 않는가
    ME.community_role = 'community_admin';
    editCommunity('c3', '리뉴젠스쿨', '', '#7B6BA0', 'academy');
    window.__upd = [];
    await saveCommunity('c3');
    out.sentByAdmin = JSON.stringify(window.__upd);
    //  총관리자가 저장하면 보내는가
    ME.community_role = 'super_admin';
    editCommunity('c3', '리뉴젠스쿨', '', '#7B6BA0', 'academy');
    document.getElementById('edit-comm-kind').value = 'community';
    window.__upd = [];
    await saveCommunity('c3');
    out.sentBySuper = JSON.stringify(window.__upd);
    return out;
  });

  ok(r.super_admin.sel, '총관리자에게는 종류 고르개가 있다');
  ok(!r.community_admin.sel, '공동체 관리자에게는 고르개가 없다');
  ok(/총관리자만 바꿉니다/.test(r.community_admin.txt),
     '공동체 관리자에게는 왜 못 바꾸는지 적어준다');
  ok(/리뉴젠 아카데미/.test(r.community_admin.txt), '지금 종류는 보여준다');
  ok(!/"kind"/.test(r.sentByAdmin),
     '공동체 관리자가 저장할 때 kind 를 보내지 않는다 ← 서버에서 막히기 전에 화면에서도 안 보낸다');
  ok(/"kind":"community"/.test(r.sentBySuper), '총관리자가 바꾸면 kind 가 간다');
  await pg.close();
}

await b.close();
done();
})();
