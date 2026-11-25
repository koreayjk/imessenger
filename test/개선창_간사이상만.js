//  💡 개선창 — 간사 이상만 보고 쓰게
//
//  2026-11-25 선교사님 지시:
//    「개선창 이제 학생들에게는 안보이게 해줘.
//      간사 이상급만보이고 작성할수있게 해줘 이제부터는」
//
//  ⚠️ 화면만 가려서는 안 됩니다. 사이드바에서 지워도
//     sessionStorage 의 last_mode 로 되돌아올 수 있고, 함수를 바로
//     부를 수도 있습니다. 그래서 세 겹으로 막습니다 —
//     ① 단추를 안 보이게 ② setMode() 에서 돌려보내기
//     ③ initImprovePage() 에서 한 번 더.
//     그리고 표의 규칙(RLS)도 같이 좁혔습니다
//     (db/개선창_간사이상만_DB설치.sql — is_school_staff()).
//
//  재는 것:
//   ① 학생·학부모에게는 사이드바 단추가 없다
//   ② 학생이 들어가려 하면 홈으로 돌아간다
//   ③ 화면 함수를 바로 불러도 글이 안 보이고 🔒 안내가 뜬다
//   ④ 간사·교사·관리자는 전과 같이 들어간다
//   ⑤ 더보기 메뉴와 홈 바로가기에도 안 나온다
//   ⑥ 역할 안내표가 「개선창 = 간사부터」 로 적혀 있다
const { launch, openApp, ok, done } = require('./_harness');

const ROLES = {
  student:         { as:'student', role:'student' },
  parent:          { as:'parent',  role:'parent'  },
  staff:           { as:'teacher', role:'staff'   },
  teacher:         { as:'teacher', role:'teacher' },
  admin_officer:   { as:'teacher', role:'admin_officer' },
  community_admin: { as:'teacher', role:'community_admin' },
  super_admin:     { as:'teacher', role:'super_admin' },
};

async function openAs(b, key) {
  const spec = ROLES[key];
  const pg = await openApp(b, { as: spec.as });
  await pg.evaluate((role) => {
    ME.community_role = role;
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
  }, spec.role);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 누가 쓸 수 있나 (판정 함수) ──────────────────────────
console.log('\n① 간사 이상인가');
{
  const pg = await openAs(b, 'student');
  const r = await pg.evaluate(() => {
    const out = {};
    ['student','parent','staff','teacher','admin_officer','community_admin','vice_admin','super_admin']
      .forEach(x => { ME.community_role = x; out[x] = canUseImprove(); });
    return out;
  });
  ok(r.student === false,         '학생은 못 쓴다 ← 이게 지시였다', String(r.student));
  ok(r.parent === false,          '학부모도 못 쓴다 (간사 아래)', String(r.parent));
  ok(r.staff === true,            '간사부터 쓸 수 있다', String(r.staff));
  ok(r.teacher === true,          '교사는 쓸 수 있다');
  ok(r.admin_officer === true,    '행정담당자도');
  ok(r.community_admin === true,  '관리자도');
  ok(r.vice_admin === true,       '부총관리자도');
  ok(r.super_admin === true,      '총관리자도');
  await pg.close();
}

// ── ② 사이드바 단추 ────────────────────────────────────────
console.log('\n② 사이드바 단추');
for (const [key, expect] of [['student',false],['parent',false],['staff',true],['teacher',true]]) {
  const pg = await openAs(b, key);
  const shown = await pg.evaluate(() => {
    const el = document.getElementById('sb-improve');
    if (!el) return null;
    //  보이기 함수를 지금 역할로 다시 돌린다
    const sbImp = document.getElementById('sb-improve');
    sbImp.style.display = canUseImprove() ? 'flex' : 'none';
    return el.style.display !== 'none';
  });
  ok(shown === expect, `${key} 에게 단추가 ${expect ? '보인다' : '안 보인다'}`, String(shown));
  await pg.close();
}

// ── ③ 들어가려 할 때 ───────────────────────────────────────
console.log('\n③ 학생이 개선창으로 가려 하면');
{
  const pg = await openAs(b, 'student');
  const r = await pg.evaluate(async () => {
    setMode('improve');
    await new Promise(r => setTimeout(r, 400));
    return { mode, viewShown: document.getElementById('improve-view').style.display };
  });
  ok(r.mode === 'home', '홈으로 돌려보낸다', r.mode);
  ok(r.viewShown === 'none', '개선창 화면이 안 열린다', r.viewShown);
  await pg.close();
}

// ── ③-2 새로고침 복원으로도 못 들어온다 ─────────────────────
console.log('\n③-2 새로고침으로 되돌아올 때');
{
  const pg = await openAs(b, 'student');
  const r = await pg.evaluate(async () => {
    //  전에 보던 화면이 개선창으로 남아 있는 상황
    sessionStorage.setItem('last_mode', 'improve');
    setMode(sessionStorage.getItem('last_mode'));
    await new Promise(r => setTimeout(r, 400));
    return { mode, saved: sessionStorage.getItem('last_mode') };
  });
  ok(r.mode === 'home',  '그래도 홈이다', r.mode);
  ok(r.saved === 'home', "다음 새로고침에도 안 들어가게 'home' 으로 바뀐다", r.saved);
  await pg.close();
}

// ── ④ 화면 함수를 바로 불러도 ───────────────────────────────
console.log('\n④ 화면 함수를 바로 부를 때');
{
  const pg = await openAs(b, 'student');
  const r = await pg.evaluate(async () => {
    window.__DB['improvements'] = [
      { id:'i1', title:'남이 쓴 개선 요청', content:'내용', status:'pending',
        author_id:'other', author_name:'홍길동', created_at:'2026-11-20T00:00:00Z' },
    ];
    await initImprovePage();
    await new Promise(r => setTimeout(r, 400));
    const page = document.getElementById('improve-main');
    return { txt: page.innerText, locked: /간사 이상만 볼 수 있어요/.test(page.innerText),
             leaked: /남이 쓴 개선 요청/.test(page.innerText),
             form: !!document.getElementById('imp-content') };
  });
  ok(r.locked, '🔒 간사 이상만 볼 수 있다고 알려 준다');
  ok(!r.leaked, '남이 쓴 글이 한 줄도 안 비친다 ← 가장 중요한 것', String(r.leaked));
  ok(!r.form, '올리는 칸도 없다', String(r.form));
  await pg.close();
}

// ── ⑤ 간사는 전과 같다 ─────────────────────────────────────
console.log('\n⑤ 간사로 들어갈 때');
{
  const pg = await openAs(b, 'staff');
  const r = await pg.evaluate(async () => {
    window.__DB['improvements'] = [
      { id:'i1', title:'개선 요청 하나', content:'내용', status:'pending',
        author_id:'other', author_name:'홍길동', created_at:'2026-11-20T00:00:00Z' },
    ];
    window.__DB['improvement_comments'] = [];
    await initImprovePage();
    await new Promise(r => setTimeout(r, 500));
    const page = document.getElementById('improve-main');
    return { sees: /개선 요청 하나/.test(page.innerText),
             locked: /간사 이상만 볼 수 있어요/.test(page.innerText),
             form: !!document.getElementById('imp-content') };
  });
  ok(r.sees,    '간사는 글이 보인다', String(r.sees));
  ok(!r.locked, '🔒 안내가 안 뜬다', String(r.locked));
  ok(r.form,    '올리는 칸도 그대로 있다', String(r.form));
  await pg.close();
}

// ── ⑥ 더보기 메뉴 · 홈 바로가기 ────────────────────────────
console.log('\n⑥ 다른 입구들');
{
  const pg = await openAs(b, 'student');
  const r = await pg.evaluate(() => {
    const menuOf = (role) => { ME.community_role = role;
      return moreMenuItems().some(it => /improve/.test(it.act)); };
    const linkOf = (role) => { ME.community_role = role;
      return HOME_LINKS.filter(l => !l.can || l.can()).some(l => l.m === 'improve'); };
    return { menuStudent: menuOf('student'), menuParent: menuOf('parent'),
             menuStaff: menuOf('staff'), menuTeacher: menuOf('teacher'),
             linkStudent: linkOf('student'), linkStaff: linkOf('staff') };
  });
  ok(!r.menuStudent, '더보기 메뉴에 학생에게는 안 나온다', String(r.menuStudent));
  ok(!r.menuParent,  '학부모에게도 안 나온다', String(r.menuParent));
  ok(r.menuStaff,    '간사에게는 나온다', String(r.menuStaff));
  ok(r.menuTeacher,  '교사에게도 나온다', String(r.menuTeacher));
  ok(!r.linkStudent, '홈 바로가기에도 학생에게는 안 나온다', String(r.linkStudent));
  ok(r.linkStaff,    '간사는 바로가기에 올릴 수 있다', String(r.linkStaff));
  await pg.close();
}

// ── ⑦ 역할 안내표 ──────────────────────────────────────────
console.log('\n⑦ 역할·권한 안내표');
{
  const pg = await openAs(b, 'teacher');
  const r = await pg.evaluate(() => {
    const imp = ROLE_CAPS.find(c => c.name === '개선창');
    const note = ROLE_CAPS.find(c => /노트/.test(c.name));
    return { has: !!imp, roles: imp ? imp.roles.slice() : [],
             noteName: note ? note.name : '' };
  });
  ok(r.has, '안내표에 「개선창」 줄이 따로 있다');
  ok(!r.roles.includes('student') && !r.roles.includes('parent'),
     '학생·학부모 칸에 ✓ 가 없다', r.roles.join(','));
  ok(r.roles.includes('staff') && r.roles.includes('super_admin'),
     '간사부터 총관리자까지 ✓ 다', r.roles.join(','));
  ok(!/개선창/.test(r.noteName),
     '「노트 · 자료실」 줄에서는 개선창을 떼어 냈다', r.noteName);
  await pg.close();
}

await b.close();
done();
})();
