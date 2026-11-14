//  🌏 부총관리자는 자기 그룹 안에서만 넘나든다
//
//    "부총관리자는 그 그룹내에서 다른 공동체를 볼수 있게.
//     리뉴젠공동체에 속한 부총관리자는 리뉴젠공동체 전체 공동체를 볼수 있게"
//
//  공동체가 한 갈래였을 땐 '부총관리자 = 전부' 가 곧 '그룹 전체' 였습니다.
//  이제 갈래가 생겼으니(리뉴젠 공동체 18곳 · 해외 그룹 2곳), 리뉴젠 공동체
//  부총관리자가 해외 그룹까지 들여다보게 둘 이유가 없습니다.
//
//  · 총관리자   : 전부
//  · 부총관리자 : 내 소속과 **같은 갈래**만
//  · 그 밖      : 내 소속 공동체만
//
//  ⚠️ 서버(mine_comm)도 같은 선을 긋습니다. 운영 DB 에서 흉내 내어
//     ① 내 소속 ✅ ② 같은 갈래 ✅ ③ 해외 그룹 ✅ 안 보임 ④ 총관리자 ✅ 보임
//     네 가지를 재서 확인했습니다. 화면에서만 가리면 질의로 꺼내 갑니다.
const { launch, openApp, ok, done } = require('./_harness');

const COMMS = [
  { id:'c1', name:'IM HQ',  kind:'community', color:'#1d3a5f' },
  { id:'c2', name:'RM',     kind:'community', color:'#2a7a5a' },
  { id:'c3', name:'프로토스', kind:'community', color:'#7B6BA0' },
  { id:'c4', name:'IM USA', kind:'overseas',  color:'#be5b2a' },
  { id:'c5', name:'IMOHP',  kind:'overseas',  color:'#B05865' },
];

async function openAs(b, role, homeId) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((d) => {
    ME.community_role = d.role;
    ME.community_id = d.home;
    ME.email = 'x@example.com';            // 총관리자 이메일 뒷문에 걸리지 않게
    VIEW_CID = null;
    window.__DB.communities = d.COMMS.map(c => Object.assign({}, c));
  }, { role, home: homeId, COMMS });
  return pg;
}
const NAMES = `(list) => visibleCommunities(list).map(c => c.name).join(',')`;

(async () => {
const b = await launch();

// ── ① 누가 어디까지 보나 ───────────────────────────────────
console.log('\n① 누가 어디까지 보나');
{
  for (const [role, home, want, label] of [
    ['vice_admin',     'c1', 'IM HQ,RM,프로토스', '리뉴젠 공동체 부총관리자'],
    ['vice_admin',     'c4', 'IM USA,IMOHP',      '해외 그룹 부총관리자'],
    ['super_admin',    'c1', 'IM HQ,RM,프로토스,IM USA,IMOHP', '총관리자'],
    ['community_admin','c1', 'IM HQ',             '공동체 관리자'],
    ['teacher',        'c2', 'RM',                '교사'],
  ]) {
    const pg = await openAs(b, role, home);
    const got = await pg.evaluate(eval(NAMES), COMMS);
    await pg.close();
    ok(got === want, `${label} → ${got || '(없음)'}`);
  }
}

// ── ② 공동체 전환 창 ──────────────────────────────────────
console.log('\n② 🏛️ 공동체 전환 창');
{
  const pg = await openAs(b, 'vice_admin', 'c1');
  const r = await pg.evaluate(async () => {
    await showCommunitySwitcher();
    const ov = document.getElementById('community-switcher-overlay');
    const out = {
      txt: ov.innerText,
      cards: [...ov.querySelectorAll('[onclick^="switchToCommunity"]')]
               .map(x => (x.getAttribute('onclick').match(/'([^']+)'/) || [])[1]),
      heads: [...ov.querySelectorAll('[data-comm-kind-head]')].map(x => x.dataset.commKindHead),
    };
    ov.remove();
    return out;
  });
  await pg.close();
  ok(r.cards.join(',') === 'c1,c2,c3', '리뉴젠 공동체 3곳만 나온다');
  ok(!/IM USA|IMOHP/.test(r.txt), '★ 해외 그룹은 전환 창에 아예 안 뜬다');
  ok(r.heads.length === 0, '갈래가 하나뿐이라 머리글을 안 붙인다 (어수선해지지 않게)');
  ok(/리뉴젠 공동체 그룹 안에서 볼 수 있어요/.test(r.txt),
     '어느 그룹 안인지 적어준다');
}
{
  //  총관리자는 그대로 전부 — 두 갈래 머리글도 뜬다
  const pg = await openAs(b, 'super_admin', 'c1');
  const r = await pg.evaluate(async () => {
    await showCommunitySwitcher();
    const ov = document.getElementById('community-switcher-overlay');
    const out = {
      cards: ov.querySelectorAll('[onclick^="switchToCommunity"]').length,
      heads: [...ov.querySelectorAll('[data-comm-kind-head]')].map(x => x.dataset.commKindHead),
    };
    ov.remove();
    return out;
  });
  await pg.close();
  ok(r.cards === 5, '총관리자에게는 5곳이 다 나온다');
  ok(r.heads.join(',') === 'community,overseas', '총관리자에게는 두 갈래로 묶여 보인다');
}

// ── ③ 해외 그룹 부총관리자 ────────────────────────────────
console.log('\n③ 해외 그룹 부총관리자');
{
  const pg = await openAs(b, 'vice_admin', 'c4');
  const r = await pg.evaluate(async () => {
    await showCommunitySwitcher();
    const ov = document.getElementById('community-switcher-overlay');
    const out = { txt: ov.innerText,
      cards: [...ov.querySelectorAll('[onclick^="switchToCommunity"]')]
               .map(x => (x.getAttribute('onclick').match(/'([^']+)'/) || [])[1]) };
    ov.remove();
    return out;
  });
  await pg.close();
  ok(r.cards.join(',') === 'c4,c5', '해외 그룹 2곳만 나온다');
  ok(!/IM HQ|프로토스/.test(r.txt), '리뉴젠 공동체 쪽은 안 보인다 ← 양쪽 다 막힌다');
  ok(/해외 그룹 그룹 안에서|해외 그룹/.test(r.txt), '자기 그룹 이름이 적힌다');
}

// ── ③-2 로그인 직후 고르기 화면 ───────────────────────────
//  ⚠️ 처음엔 거르는 일을 부르는 쪽(로그인 흐름)에서만 했더니, 되돌려도
//     시험이 못 잡았다. 그리는 자리로 옮기고 여기서 잰다.
console.log('\n③-2 로그인 직후 고르기 화면');
{
  for (const [role, home, want, label] of [
    ['vice_admin',  'c1', 'c1,c2,c3',          '리뉴젠 공동체 부총관리자'],
    ['vice_admin',  'c4', 'c4,c5',             '해외 그룹 부총관리자'],
    ['super_admin', 'c1', 'c1,c2,c3,c4,c5',    '총관리자'],
  ]) {
    const pg = await openAs(b, role, home);
    const r = await pg.evaluate((C) => {
      showCommunitySelect(C);
      const el = document.getElementById('community-list');
      const out = {
        ids: [...el.querySelectorAll('[onclick^="enterCommunity"]')]
               .map(x => (x.getAttribute('onclick').match(/'([^']+)'/) || [])[1]),
        txt: el.innerText,
      };
      document.getElementById('community-select-screen').style.display = 'none';
      return out;
    }, COMMS);
    await pg.close();
    ok(r.ids.join(',') === want, `${label} → ${r.ids.join(',') || '(없음)'}`);
    if (role === 'vice_admin' && home === 'c1') {
      ok(!/IM USA|IMOHP/.test(r.txt), '★ 여기서도 해외 그룹은 안 뜬다');
    }
  }
}

// ── ④ 관리 권한은 그대로 '내 소속만' ──────────────────────
console.log("\n④ 보는 것과 관리하는 것은 다르다");
{
  const pg = await openAs(b, 'vice_admin', 'c1');
  const r = await pg.evaluate(() => {
    const out = {};
    VIEW_CID = null;  out.home = { guest: isGuestViewing(), admin: isCommunityAdmin() };
    VIEW_CID = 'c2';  out.away = { guest: isGuestViewing(), admin: isCommunityAdmin() };
    VIEW_CID = null;
    return out;
  });
  await pg.close();
  ok(r.home.admin === true && r.home.guest === false,
     '내 소속에서는 관리자다');
  ok(r.away.admin === false && r.away.guest === true,
     '같은 갈래라도 남의 공동체에서는 보기·채팅만 된다 ← 넓어진 건 보는 범위뿐이다');
}

await b.close();
done();
})();
