//  📅 입소증명서 — 생기부에 적힌 입소일을 자동으로
//
//    "생기부에 등록된 입소일을 자동으로 반영되게 할 수 있을까요?
//     지금 신청하신 분은 처리했습니다. 수기로요!"  (Grace)
//
//  운영에서 재 보니 생기부(school)에 입소일이 적힌 학생이 18/73 명,
//  프로필(members.enroll_date)에 적힌 사람이 4명, 겹치는 사람은 0명이라
//  부딪힐 일이 없습니다. 생기부를 먼저 쓰고 없으면 프로필을 씁니다.
//
//  ★ 여기서 재는 것
//   ① 생기부에 입소일이 있으면 그 날짜가 칸에 들어간다 (오늘이 아니라)
//   ② 생기부에 없으면 프로필의 입학일을 쓴다
//   ③ 둘 다 없으면 오늘을 띄우고, **오늘을 띄웠다고 알려 준다**
//      — 모르고 찍으면 입소일이 틀린 증명서가 나간다
//   ④ ⚠️ 학생을 바꾸면 날짜도 따라 바뀐다
//      — 안 비우면 앞 학생 날짜가 다른 아이 증명서에 찍힌다
//   ⑤ 증서 문장에도 그 날짜가 들어간다
const { launch, openApp, ok, done } = require('./_harness');

//  학생 셋 — 생기부에 있음 / 프로필에만 있음 / 아무 데도 없음
const STU = [
  { id:'s1', name:'생기부있음', community_role:'student', status:'approved', birth_date:'2010-03-15' },
  { id:'s2', name:'프로필만',   community_role:'student', status:'approved', birth_date:'2011-04-20', enroll_date:'2024-09-02' },
  { id:'s3', name:'아무데도없음', community_role:'student', status:'approved', birth_date:'2012-05-25' },
];

async function open1(b) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((stu) => {
    ME.community_id = 'c1'; ME.community_role = 'community_admin';
    const sv = document.getElementById('school-view'); if (sv) sv.style.display = 'flex';
    window.__DB.communities = [{ id:'c1', name:'그레이스 미니스트리', kind:'community' }];
    window.__DB.members = stu.map(x => Object.assign({ community_id:'c1' }, x));
    window.__DB.tcs_records = [
      { id:'r1', student_id:'s1', section:'school',
        data:{ school_name:'그레이스 미니스트리', enroll_date:'2025-08-18' } },
      { id:'r2', student_id:'s1', section:'personal', data:{ birth:'2010-03-15' } },
      //  s2·s3 는 생기부에 입소일이 없다
      { id:'r3', student_id:'s2', section:'school', data:{ school_name:'그레이스' } },
    ];
    window.__DB.record_orgs = [{ id:'o1', community_id:'c1', name:'그레이스', address:'' }];
    window.__DB.org_seals = []; window.__DB.cert_requests = []; window.__DB.cert_forms = [];
    schoolStudents = stu.map(x => Object.assign({ community_id:'c1' }, x));
    tcsOrgs = [{ id:'o1', name:'그레이스', address:'' }]; tcsSelectedOrgId = 'o1'; orgSeals = [];
    certSubTab = 'issue'; certLang = 'ko'; certType = 'admit';
    certAdmitDate = '';
  }, STU);
  return pg;
}

//  사람이 하듯 — 학생을 고르고, 종류를 입소증명서로 고른다
const pick = (pg, id) => pg.evaluate(async (id) => {
  await certLoadStudent(id);
  renderCert();
  const sel = document.getElementById('cert-type');
  sel.value = 'admit'; certOnType('admit');
  const di = document.getElementById('cert-admit');
  const dn = document.getElementById('cert-admit-note');
  return { date: di ? di.value : null, state: certAdmitDate,
           note: dn ? dn.innerText : '', prefill: certPrefill.enroll };
}, id);

(async () => {
const b = await launch();
const today = new Date();
const TODAY = today.getFullYear() + '-' + String(today.getMonth()+1).padStart(2,'0')
            + '-' + String(today.getDate()).padStart(2,'0');

// ── ① 생기부에 있으면 ───────────────────────────────────────────
console.log('\n① 생기부에 입소일이 적힌 학생');
{
  const pg = await open1(b);
  const r = await pick(pg, 's1');
  ok(r.date === '2025-08-18', '생기부의 입소일이 칸에 들어간다', r.date);
  ok(r.date !== TODAY, '오늘 날짜가 아니다', r.date + ' vs 오늘 ' + TODAY);
  ok(/생기부에 적힌 입소일을 가져왔어요/.test(r.note), '어디서 온 날짜인지 알려 준다', r.note);

  //  ⚠️ 칸을 지웠다가 종류를 다시 고르면 **오늘이 아니라 생기부 날짜**로
  //     다시 채워져야 합니다. 여기를 안 재면 그 줄이 죽은 코드가 되고,
  //     되돌려 놓아도 시험이 통과해 버립니다 (여기서 한 번 데었습니다).
  const again = await pg.evaluate(() => {
    const di = document.getElementById('cert-admit');
    di.value = ''; certAdmitDate = '';      // 사람이 칸을 지운 상황
    certSyncType();
    return { date: di.value, note: (document.getElementById('cert-admit-note')||{}).innerText || '' };
  });
  ok(again.date === '2025-08-18',
     '칸을 지웠다가 다시 그려도 생기부 날짜로 채운다 (오늘이 아니라)', again.date);
  ok(/생기부에 적힌 입소일/.test(again.note), '그때도 어디서 왔는지 알려 준다', again.note);
  await pg.close();
}

// ── ② 프로필에만 있으면 ─────────────────────────────────────────
console.log('\n② 생기부엔 없고 프로필(입학일)에만 있는 학생');
{
  const pg = await open1(b);
  const r = await pick(pg, 's2');
  ok(r.date === '2024-09-02', '프로필의 입학일을 쓴다', r.date);
  await pg.close();
}

// ── ③ 둘 다 없으면 ──────────────────────────────────────────────
console.log('\n③ 아무 데도 입소일이 없는 학생');
{
  const pg = await open1(b);
  const r = await pick(pg, 's3');
  ok(r.date === TODAY, '오늘을 띄운다', r.date);
  ok(/오늘 날짜/.test(r.note) && /확인해 주세요/.test(r.note),
     '오늘을 띄웠다고 알려 준다 — 모르고 찍으면 틀린 증명서가 나간다', r.note);
  await pg.close();
}

// ── ④ 학생을 바꿨을 때 ──────────────────────────────────────────
console.log('\n④ ⚠️ 학생을 바꾸면 날짜도 따라 바뀌어야 한다');
{
  const pg = await open1(b);
  const a = await pick(pg, 's1');
  const c = await pick(pg, 's3');
  const back = await pick(pg, 's1');
  ok(a.date === '2025-08-18', '먼저 고른 학생은 생기부 날짜', a.date);
  ok(c.date === TODAY,
     '다음 학생으로 바꾸면 앞 학생 날짜가 남지 않는다 ← 안 비우면 남의 날짜가 찍힌다', c.date);
  ok(back.date === '2025-08-18', '다시 돌아오면 그 학생 날짜로 돌아온다', back.date);
  await pg.close();
}

// ── ⑤ 증서 문장에 들어가나 ──────────────────────────────────────
console.log('\n⑤ 증서 문장');
{
  const pg = await open1(b);
  await pick(pg, 's1');
  const r = await pg.evaluate(async () => {
    window.__printed = [];
    window.open = () => ({ document:{ open(){}, close(){}, write(h){ window.__printed.push(String(h)); } }, close(){} });
    const sbr = sb.rpc.bind(sb);
    sb.rpc = (name, args) => {
      if (name === 'issue_certificate') { window.__issued = args.p;
        return Promise.resolve({ data:{ id:'c1', cert_no:'2026-0001' }, error:null }); }
      return sbr(name, args);
    };
    await printCertificate();
    await new Promise(r => setTimeout(r, 200));
    return { stmt: (window.__issued || {}).statement || '', html: (window.__printed||[]).join('\n') };
  });
  ok(/8월 18일/.test(r.stmt), '문장에 생기부의 입소일이 들어간다', r.stmt);
  ok(!/오늘/.test(r.stmt), '오늘 날짜가 아니다', r.stmt);
  await pg.close();
}

done(b);
})();
