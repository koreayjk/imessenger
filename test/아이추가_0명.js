//  👨‍👩‍👧 아이가 **한 명도 없는** 학부모도 아이를 신청할 수 있어야 한다
//
//  왜 이 시험이 있나
//    '＋ 아이 추가' 버튼을 아이 칩 줄(childChipsHtml) 에만 달아 뒀습니다.
//    그런데 그 줄은 **아이가 한 명 이상일 때만** 그려집니다. 그래서
//    아이가 0명인 분 — 가입할 때 아이를 안 이어 준 분, 이를테면 관리자가
//    학생으로 들어온 계정을 학부모로 바꿔 준 경우 — 은 안내문만 보고
//    **아무것도 못 했습니다.** 버튼은 0명일 때가 제일 필요합니다.
//    (실제로 Grace 님이 막혔습니다.)
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();

// ── ① 아이가 0명일 때 ────────────────────────────────────────
console.log('\n① 아이가 한 명도 없는 학부모');
{
  const pg = await openApp(b, { as:'parent' });   // 홍어머니 = p1
  const r = await pg.evaluate(async () => {
    window.__DB.student_parents = [];             // 아직 아무와도 안 이어짐
    childList = [];
    delete ME.parent_claim_name;
    await initChildPage();
    const main = document.getElementById('child-main');
    return {
      버튼: !!main.querySelector('[onclick^="openAddChildModal"]'),
      글: main.textContent.replace(/\s+/g,' '),
    };
  });
  ok(r.버튼, '＋ 아이 추가 버튼이 보인다 — 이게 없어서 길이 막혔다');
  ok(/아직 아이와 연결되지 않았어요|Not linked/.test(r.글), '안내 글은 그대로 있다');
  ok(/직접 신청|request your child/i.test(r.글), '직접 신청할 수 있다고 알려 준다');
  await pg.close();
}

// ── ② 이미 신청해 둔 게 있을 때 ──────────────────────────────
console.log('\n② 이미 신청해 둔 게 있을 때');
{
  const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(async () => {
    window.__DB.student_parents = [];
    childList = [];
    ME.parent_claim_name = '홍길동'; ME.parent_claim_birth = '2011-03-04';
    await initChildPage();
    const main = document.getElementById('child-main');
    return { 글: main.textContent.replace(/\s+/g,' '),
             버튼: !!main.querySelector('[onclick^="openAddChildModal"]') };
  });
  ok(/홍길동/.test(r.글), '신청해 둔 아이 이름이 보인다');
  ok(/기다|확인해 주시면|confirm/i.test(r.글), '선생님 확인을 기다리는 중이라고 알려 준다');
  ok(r.버튼, '그래도 버튼은 남는다 (다른 아이를 적을 수 있어야 한다)');
  await pg.close();
}

// ── ③ 신청 창이 열린다 ───────────────────────────────────────
console.log('\n③ 신청 창');
{
  const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(async () => {
    window.__DB.student_parents = [];
    childList = [];
    delete ME.parent_claim_name;
    await initChildPage();
    document.querySelector('[onclick^="openAddChildModal"]').click();
    const m = document.querySelector('.add-child-modal');
    return {
      열림: !!m,
      이름칸: !!document.getElementById('ac-name'),
      생일칸: !!document.getElementById('ac-birth'),
      관계칸: !!document.getElementById('ac-rel'),
    };
  });
  ok(r.열림, '아이 추가 창이 열린다 (아이가 0명이어도 터지지 않는다)');
  ok(r.이름칸 && r.생일칸 && r.관계칸, '이름 · 생년월일 · 관계 칸이 다 있다');
  await pg.close();
}

// ── ④ 관리자 쪽 — 신청을 보고 이어 줄 수 있나 ────────────────
console.log('\n④ 관리자가 신청을 보고 잇는다');
{
  const pg = await openApp(b, { as:'teacher' });   // 김선생 = community_admin
  const r = await pg.evaluate(async () => {
    window.__DB.student_parents = [];
    window.__DB.members = [
      { id:'me', name:'김선생', community_id:'c1', community_role:'community_admin', status:'approved' },
      { id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent', status:'approved',
        parent_claim_name:'홍길동', parent_claim_birth:'2011-03-04', parent_claim_rel:'모' },
      { id:'p2', name:'김아버지', community_id:'c1', community_role:'parent', status:'approved' },
    ];
    await renderAdminMembers();
    const rows = [...document.querySelectorAll('#admin-content .adm-row')];
    const row = (nm) => rows.find(x => x.textContent.includes(nm));
    const look = (nm) => { const x = row(nm); return x ? {
      잇기: !!x.querySelector('[onclick^="admLinkClaimedChild"]'),
      글: x.textContent.replace(/\s+/g,' ') } : null; };
    return { 신청있음: look('홍어머니'), 신청없음: look('김아버지') };
  });

  ok(r.신청있음 && r.신청있음.잇기, '신청한 학부모 줄에 🔗 아이 연결 버튼이 뜬다');
  ok(r.신청있음 && /홍길동/.test(r.신청있음.글), '적어 낸 아이 이름이 보인다');
  ok(r.신청있음 && /2011-03-04/.test(r.신청있음.글), '생년월일도 보인다 (동명이인을 가리려면 필요하다)');
  ok(r.신청없음 && !r.신청없음.잇기, '신청이 없는 학부모에게는 버튼이 안 뜬다');
  await pg.close();
}

await b.close();
done();
})();
