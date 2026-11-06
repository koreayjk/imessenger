//  👨‍👩‍👧 학부모 명단 — 간사·교사도 본다 (개선창 · 홍예원 간사)
//
//    "간사 & 교사도 학부모 명단을 확인하며 체크 할 수 있게 해주셨으면"
//
//  서버는 이미 열려 있었습니다(같은 공동체면 보입니다). 막힌 건 화면이었고,
//  명단이 관리자 페이지 안에만 있어서 간사·교사는 들어갈 수가 없었습니다.
//  학사 탭으로 옮기면 canAccessSchool() 이 열어 주는 자리라 간사·교사는
//  들어오고 **학생·학부모는 못 들어옵니다.** 그 선을 글로 못 박습니다.
const { launch, openApp, ok, done } = require('./_harness');

const SEED = [
  { id:'me', name:'김선생', community_id:'c1', community_role:'community_admin', status:'approved' },
  { id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent', status:'approved', phone:'010-1111-2222', email:'hong@example.com' },
  { id:'p2', name:'김아버지', community_id:'c1', community_role:'parent', status:'approved', email:'kim@example.com' },
  { id:'p3', name:'떠난학부모', community_id:'c1', community_role:'parent', status:'removed' },
  { id:'p9', name:'남공동체학부모', community_id:'c9', community_role:'parent', status:'approved' },
  { id:'s1', name:'홍길동', community_id:'c1', community_role:'student', status:'approved' },
];
const LINKS = [{ id:'sp1', student_id:'s1', parent_id:'p1' }];

(async () => {
const b = await launch();

// ── ① 누가 탭을 보나 ─────────────────────────────────────────
console.log('\n① 누가 학부모 탭을 보나');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    const has = () => SCHOOL_TABS.filter(x => x.section === 'school')
      .filter(x => !x.admin || canSeeAdminModules()).some(x => x.id === 'parents') && canAccessSchool();
    const out = {};
    for (const role of ['community_admin','admin_officer','teacher','staff','vice_admin','super_admin','student','parent']) {
      ME.community_role = role; out[role] = has();
    }
    ME.community_role = 'community_admin';
    return out;
  });
  ok(r.staff,   '간사에게 보인다 ← 이게 요청이었다');
  ok(r.teacher, '교사에게 보인다 ← 이것도');
  ok(r.community_admin && r.admin_officer && r.vice_admin && r.super_admin, '관리자급에게도 그대로 보인다');
  ok(!r.student, '학생에게는 안 보인다');
  ok(!r.parent,  '학부모에게는 안 보인다 — 서로의 연락처를 보면 안 된다');
  await pg.close();
}

// ── ② 명단 ───────────────────────────────────────────────────
console.log('\n② 명단');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.members = d.SEED; window.__DB.student_parents = d.LINKS;
    parFind = ''; parOnlyUnlinked = false;
    try { localStorage.removeItem('tcs_par_check_c1'); } catch (_) {}
    await renderParentsHub();
    const main = document.getElementById('school-main');
    return { ids: [...main.querySelectorAll('[data-par]')].map(x => x.getAttribute('data-par')),
             txt: main.textContent.replace(/\s+/g,' ') };
  }, { SEED, LINKS });

  ok(r.ids.length === 2, '우리 공동체 학부모 두 분만 나온다 (' + r.ids.join(', ') + ')');
  ok(!r.ids.includes('p3'), '탈퇴한 분은 안 나온다');
  ok(!r.ids.includes('p9'), '다른 공동체 학부모는 안 나온다');
  ok(!r.ids.includes('s1'), '학생은 안 섞인다');
  ok(/010-1111-2222/.test(r.txt), '연락처가 보인다');
  ok(/홍길동/.test(r.txt), '어느 아이의 보호자인지 보인다');
  ok(/아직 아이와 연결 안 됨|Not linked/.test(r.txt), '연결 안 된 분은 표가 붙는다');
  await pg.close();
}

// ── ③ 찾기 · 거르기 ──────────────────────────────────────────
console.log('\n③ 찾기와 거르기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.members = d.SEED; window.__DB.student_parents = d.LINKS;
    parFind = ''; parOnlyUnlinked = false;
    await renderParentsHub();
    const ids = () => [...document.querySelectorAll('#school-main [data-par]')].map(x => x.getAttribute('data-par'));
    const out = {};
    parSetFind('홍길동');  out.아이이름으로 = ids();
    parSetFind('kim@');    out.메일로 = ids();
    parSetFind('');
    parToggleUnlinked();   out.연결안된분만 = ids();
    parToggleUnlinked();
    return out;
  }, { SEED, LINKS });
  ok(JSON.stringify(r.아이이름으로) === JSON.stringify(['p1']), '아이 이름으로 그 학부모를 찾는다');
  ok(JSON.stringify(r.메일로) === JSON.stringify(['p2']), '메일로도 찾는다');
  ok(JSON.stringify(r.연결안된분만) === JSON.stringify(['p2']), '연결 안 된 분만 걸러 본다');
  await pg.close();
}

// ── ④ 체크 ───────────────────────────────────────────────────
console.log('\n④ 체크 표시');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.members = d.SEED; window.__DB.student_parents = d.LINKS;
    parFind = ''; parOnlyUnlinked = false;
    try { localStorage.removeItem('tcs_par_check_c1'); } catch (_) {}
    await renderParentsHub();
    parToggle('p1');
    const savedRaw = localStorage.getItem('tcs_par_check_c1');
    const 켜짐 = !!document.querySelector('#school-main [data-par="p1"] input[type=checkbox]:checked');
    //  다시 그려도 남아야 한다
    parPaint();
    const 다시켜짐 = !!document.querySelector('#school-main [data-par="p1"] input[type=checkbox]:checked');
    parToggle('p1');
    const 꺼짐 = !document.querySelector('#school-main [data-par="p1"] input[type=checkbox]:checked');
    return { savedRaw, 켜짐, 다시켜짐, 꺼짐,
             서버로갔나: (window.__upd||[]).length + (window.__ins||[]).length };
  }, { SEED, LINKS });

  ok(r.켜짐, '체크하면 켜진다');
  ok(r.다시켜짐, '다시 그려도 남는다');
  ok(r.꺼짐, '다시 누르면 꺼진다');
  ok(/p1/.test(r.savedRaw || ''), '내 기기(localStorage)에 남는다');
  ok(r.서버로갔나 === 0, '서버에는 아무것도 안 보낸다 — 나만 보이는 표시다');
  await pg.close();
}

await b.close();
done();
})();
