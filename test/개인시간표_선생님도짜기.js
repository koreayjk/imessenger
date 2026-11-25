//  🗓 개인 시간표 — 선생님도 아이 것을 짜 주기
//
//  개선창 · 홍예원 (IM HQ, 11/20):
//    「공통일정 말고 개인 일정으로 설정할 수 있었으면 좋겠습니다!
//      생기부 >> 시간표 / 이 부분은 다 공통이더라구요ㅠㅜ」
//
//  재 보니 개인 시간표(student_timetables)는 **이미 있었습니다.** 다만
//  쓰기 규칙이 member_id = auth.uid() 하나뿐이어서 학생 본인만 짤 수
//  있었고, 선생님은 생기부에서 보기만 했습니다. 아이가 안 짜면 선생님이
//  할 수 있는 일이 없었습니다. (홍예원님이 보신 「다 공통」 화면은
//  학사 ▸ 시간표 — 그건 반 단위 시간표라 원래 공통입니다.)
//
//  그래서 생기부 카드에 「✏️ 짜 주기」 를 달고, 서버 규칙도 같이
//  넓혔습니다 (db/개인시간표_선생님도쓰기_DB설치.sql —
//  같은 공동체 아이만. 다른 공동체 선생님은 못 건드립니다).
//
//  재는 것:
//   ① 생기부 카드에 교직원에게만 「짜 주기」 가 보인다
//   ② 누르면 그 아이 시간표를 불러온다 (내 것이 아니다)
//   ③ 넣으면 그 아이 줄로 들어간다 (member_id 가 아이)
//   ④ 누구 것을 짜는 중인지 화면에 적어 준다
//   ⑤ 돌아가면 그 아이 생기부로 가고, 다시 내 것이 된다
//   ⑥ 학생은 남의 것을 열 수 없다 (함수를 직접 불러도)
const { launch, openApp, ok, done } = require('./_harness');

const STUDENTS = [
  { id:'st1', name:'홍길동', grade:'G7', community_id:'c1' },
  { id:'st2', name:'김영희', grade:'G8', community_id:'c1' },
];
const ROWS = [
  { id:'e1', member_id:'st1', community_id:'c1', day:2, start_time:'13:00',
    end_time:'14:00', subject:'아이 수업', place:'', color:'#2a5298' },
  { id:'e9', member_id:'me',  community_id:'c1', day:1, start_time:'09:00',
    end_time:'10:00', subject:'내 수업',   place:'', color:'#2a5298' },
];

async function open(b, who) {
  const pg = await openApp(b, { as: who === 'student' ? 'student' : 'teacher' });
  await pg.evaluate(([ss, rows, role]) => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1'; ME.community_role = role;
    //  ⚠️ schoolStudents 만 넣으면 안 됩니다. setMode('school') 이 학생
    //     목록을 표에서 다시 읽어서, 표에 없는 아이는 사라지고 s360Id 가
    //     다른 아이로 바뀝니다 — 여기서 한 번 틀렸습니다.
    schoolStudents = JSON.parse(JSON.stringify(ss));
    window.__DB.members = (window.__DB.members || [])
      .filter(m => !ss.some(x => x.id === m.id))
      .concat(ss.map(x => ({ ...x, community_role:'student', status:'approved' })));
    ss.forEach(x => { members[x.id] = { ...x, community_role:'student' }; });
    schoolTeachers = [{ id:'me', name:'김선생' }];
    window.__DB['student_timetables'] = JSON.parse(JSON.stringify(rows));
    myTT = []; ttOwner = null; ttSelectedId = null; mttDays = [1]; mttKind = 'class';
    mttTerm = ttDefaultTerm();
    s360Id = 'st1';
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    ['mytt-main','school-main'].forEach(id => {
      document.getElementById(id) ||
        document.body.insertAdjacentHTML('beforeend', `<div id="${id}"></div>`);
    });
  }, [STUDENTS, ROWS, who === 'student' ? 'student' : 'teacher']);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 카드의 단추 ──────────────────────────────────────────
console.log('\n① 생기부 카드의 「짜 주기」');
{
  const pg = await open(b, 'teacher');
  const r = await pg.evaluate(() => {
    const asTeacher = s360TimetableCard([]);
    ME.community_role = 'student';
    const asStudent = s360TimetableCard([]);
    ME.community_role = 'teacher';
    return {
      teacher: /ttEditFor/.test(asTeacher),
      student: /ttEditFor/.test(asStudent),
      points:  /ttEditFor\('st1','홍길동'\)/.test(asTeacher),
    };
  });
  ok(r.teacher, '교직원에게는 「짜 주기」 가 보인다');
  ok(!r.student, '학생에게는 안 보인다', String(r.student));
  ok(r.points, '지금 보고 있는 아이를 가리킨다');
  await pg.close();
}

// ── ②③④ 눌러서 짜 주기 ────────────────────────────────────
console.log('\n② 눌러서 그 아이 것을 불러온다');
{
  const pg = await open(b, 'teacher');
  const r = await pg.evaluate(async () => {
    ttEditFor('st1', '홍길동');
    await new Promise(r => setTimeout(r, 600));
    await initMyTimetable();
    await new Promise(r => setTimeout(r, 400));
    return {
      owner: ttOwner && ttOwner.id,
      ownerId: ttOwnerId(),
      forOther: ttForOther(),
      loaded: myTT.map(e => [e.member_id, e.subject]),
      mode,
    };
  });
  ok(r.mode === 'mytt',      '개인 시간표 화면으로 간다', r.mode);
  ok(r.owner === 'st1',      '그 아이를 짜는 중으로 잡힌다', r.owner);
  ok(r.ownerId === 'st1',    'ttOwnerId() 가 아이 id 다', r.ownerId);
  ok(r.forOther === true,    '내 것이 아니라고 안다', String(r.forOther));
  ok(r.loaded.length === 1 && r.loaded[0][0] === 'st1',
     '아이 시간표만 불러온다 (내 것은 안 섞인다)', JSON.stringify(r.loaded));

  console.log('\n③ 넣으면 아이 줄로');
  const w = await pg.evaluate(async () => {
    document.getElementById('mtt-start').value = '15:00';
    document.getElementById('mtt-end').value   = '16:30';
    document.getElementById('mtt-subject').value = '선생님이 넣은 수업';
    document.getElementById('mtt-place').value   = '201호';
    await addMyTTEntry();
    await new Promise(r => setTimeout(r, 500));
    const ins = (window.__ins || []).filter(x => x.t === 'student_timetables');
    return ins.flatMap(x => x.rows);
  });
  ok(w.length === 1, '한 줄 들어간다', w.length);
  ok(w[0] && w[0].member_id === 'st1', 'member_id 가 아이다 ← 이게 핵심', w[0] && w[0].member_id);
  ok(w[0] && w[0].subject === '선생님이 넣은 수업', '적은 내용이 들어간다', w[0] && w[0].subject);
  ok(w[0] && w[0].community_id === 'c1', '공동체도 함께 들어간다', w[0] && w[0].community_id);

  console.log('\n④ 누구 것인지 적어 준다');
  const h = await pg.evaluate(() => {
    renderMyTimetable();
    const txt = document.getElementById('mytt-main').innerText;
    return { txt, back: !!document.querySelector('[onclick="ttBackToStudent()"]') };
  });
  ok(/홍길동/.test(h.txt), '아이 이름이 적혀 있다');
  ok(/대신 짜는 중/.test(h.txt), '대신 짜는 중이라고 알려 준다');
  ok(h.back, '생기부로 돌아가는 단추가 있다');
  await pg.close();
}

// ── ⑤ 돌아가기 ─────────────────────────────────────────────
console.log('\n⑤ 돌아가면');
{
  const pg = await open(b, 'teacher');
  const r = await pg.evaluate(async () => {
    ttEditFor('st2', '김영희');
    await new Promise(r => setTimeout(r, 400));
    ttBackToStudent();
    await new Promise(r => setTimeout(r, 500));
    return { owner: ttOwner, ownerId: ttOwnerId(), s360: s360Id,
             sub: schoolSubMode, mode };
  });
  ok(r.owner === null,      '대신 짜기가 끝난다', JSON.stringify(r.owner));
  ok(r.ownerId === 'me',    '다시 내 것이 된다', r.ownerId);
  ok(r.s360 === 'st2',      '그 아이 생기부로 돌아간다', r.s360);
  ok(r.sub === 'student',   '학생 상세 화면으로 간다', r.sub);
  ok(r.mode === 'school',   '학사 화면이다', r.mode);
  await pg.close();
}

// ── ⑥ 학생은 남의 것을 못 연다 ──────────────────────────────
console.log('\n⑥ 학생이 함수를 직접 부르면');
{
  const pg = await open(b, 'student');
  const r = await pg.evaluate(async () => {
    window.__toast = [];
    ttEditFor('st1', '홍길동');
    await new Promise(r => setTimeout(r, 300));
    const blocked = { owner: ttOwner, toast: window.__toast.join('|') };
    //  변수를 억지로 넣어도
    ttOwner = { id:'st1', name:'홍길동' };
    const forced = ttOwnerId();
    await initMyTimetable();
    await new Promise(r => setTimeout(r, 400));
    return { blocked, forced, cleared: ttOwner,
             loaded: myTT.map(e => e.member_id) };
  });
  ok(r.blocked.owner === null, '「짜 주기」 가 안 열린다', JSON.stringify(r.blocked.owner));
  ok(/권한이 없어요/.test(r.blocked.toast), '권한이 없다고 말해 준다', r.blocked.toast);
  ok(r.forced === 'me', '변수를 억지로 넣어도 내 id 로 돌아온다 ← 가장 중요한 것', r.forced);
  ok(r.cleared === null, '화면을 열 때 그 변수를 지운다', JSON.stringify(r.cleared));
  ok(!r.loaded.includes('st1'), '아이 시간표가 한 줄도 안 읽힌다', r.loaded.join(','));
  await pg.close();
}

await b.close();
done();
})();
