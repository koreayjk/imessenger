//  🎂 생년월일 — 년·월·일을 따로 고른다
//
//  왜 고쳤나
//    <input type="date"> 는 폰에서 **오늘**부터 열립니다. 2008년생을 적으려면
//    화살표를 20번 넘게 눌러야 했습니다. 가입하신 분이 그대로 말씀하셨습니다:
//    "2026년부터 2008년1월까지 20번이상은 계속 눌러야 하네요"
//    연도를 목록으로 두면 한 번에 갑니다.
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();

// ── ① 가입 화면 ──────────────────────────────────────────────
console.log('\n① 가입 화면의 생년월일 칸');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    suBirthLimit();                       // 고르개를 끼운다
    const y = document.getElementById('su-birth-y');
    const m = document.getElementById('su-birth-m');
    const d = document.getElementById('su-birth-d');
    const years = y ? [...y.options].map(o => o.value).filter(Boolean).map(Number) : [];
    return {
      세칸: !!(y && m && d),
      달력남았나: !!document.querySelector('#su-birth input[type=date]'),
      연도수: years.length,
      맨위: years[0], 맨아래: years[years.length-1],
      이천팔있나: years.includes(2008),
      달수: m ? [...m.options].filter(o => o.value).length : 0,
      날수: d ? [...d.options].filter(o => o.value).length : 0,
      아이칸: !!document.getElementById('su-child-birth-y'),
    };
  });

  ok(r.세칸, '년 · 월 · 일 세 칸으로 바뀌었다');
  ok(!r.달력남았나, '옛 달력(input type=date)은 남아 있지 않다');
  ok(r.이천팔있나, '2008년이 목록에 바로 있다 — 20번 누를 일이 없다');
  ok(r.연도수 === 121, '올해부터 120년 전까지 열려 있다 (' + r.맨위 + ' ~ ' + r.맨아래 + ')');
  ok(r.맨위 === new Date().getFullYear(), '맨 위는 올해 — 미래는 아예 못 고른다');
  ok(r.달수 === 12 && r.날수 === 31, '달 12칸 · 날 31칸이 처음부터 들어 있다 (창 뜨자마자 고를 수 있어야 한다)');
  ok(r.아이칸, '학부모의 「아이 생년월일」 칸도 같이 바뀌었다');
  await pg.close();
}

// ── ② 고른 값 ────────────────────────────────────────────────
console.log('\n② 고른 값이 YYYY-MM-DD 로 나온다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    suBirthLimit();
    const set = (y,m,d) => {
      document.getElementById('su-birth-y').value = y;
      document.getElementById('su-birth-m').value = m;
      birthSyncDays('su-birth');
      document.getElementById('su-birth-d').value = d;
      return birthValue('su-birth');
    };
    const out = {};
    out.정상 = set('2008','01','05');
    out.한자리달 = set('2011','09','09');
    document.getElementById('su-birth-d').value = '';
    out.날만뺌 = birthValue('su-birth');
    document.getElementById('su-birth-y').value = '';
    document.getElementById('su-birth-m').value = '';
    out.다뺌 = birthValue('su-birth');
    return out;
  });
  ok(r.정상 === '2008-01-05', "2008년 1월 5일 → '2008-01-05' (지금: " + r.정상 + ')');
  ok(r.한자리달 === '2011-09-09', '한 자리 달·날도 0 을 붙인다 (' + r.한자리달 + ')');
  ok(r.날만뺌 === '', '세 칸 중 하나라도 비면 빈 값 — 반쪽짜리 날짜가 저장되면 안 된다');
  ok(r.다뺌 === '', '다 비어도 빈 값');
  await pg.close();
}

// ── ③ 달마다 날 수가 다르다 ──────────────────────────────────
console.log('\n③ 2월 30일 같은 건 못 고른다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    suBirthLimit();
    const days = (y,m) => {
      document.getElementById('su-birth-y').value = y;
      document.getElementById('su-birth-m').value = m;
      birthSyncDays('su-birth');
      return [...document.getElementById('su-birth-d').options].filter(o => o.value).length;
    };
    const out = { 평년2월: days('2011','02'), 윤년2월: days('2008','02'),
                  사월: days('2008','04'), 오월: days('2008','05') };
    //  31일을 고른 뒤 2월로 바꾸면?
    document.getElementById('su-birth-y').value = '2011';
    document.getElementById('su-birth-m').value = '01';
    birthSyncDays('su-birth');
    document.getElementById('su-birth-d').value = '31';
    document.getElementById('su-birth-m').value = '02';
    birthSyncDays('su-birth');
    out.당겨짐 = birthValue('su-birth');
    return out;
  });
  ok(r.평년2월 === 28, '2011년 2월은 28일까지');
  ok(r.윤년2월 === 29, '2008년 2월은 29일까지 (윤년)');
  ok(r.사월 === 30 && r.오월 === 31, '4월 30일 · 5월 31일');
  ok(r.당겨짐 === '2011-02-28', '1월 31일을 고른 뒤 2월로 바꾸면 28일로 당긴다 (' + r.당겨짐 + ')');
  await pg.close();
}

// ── ④ 아이 추가 창 ───────────────────────────────────────────
console.log('\n④ 아이 추가 창');
{
  const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(async () => {
    window.__DB.student_parents = [];
    childList = []; delete ME.parent_claim_name;
    await initChildPage();
    document.querySelector('[onclick^="openAddChildModal"]').click();
    const y = document.getElementById('ac-birth-y');
    const d = document.getElementById('ac-birth-d');
    if (y) { y.value = '2008'; document.getElementById('ac-birth-m').value = '01';
             birthSyncDays('ac-birth'); d.value = '20'; }
    return { 세칸: !!(y && d && document.getElementById('ac-birth-m')),
             값: birthValue('ac-birth'),
             달력남았나: !!document.querySelector('#ac-birth input[type=date]') };
  });
  ok(r.세칸, '아이 추가 창도 년 · 월 · 일 세 칸이다');
  ok(!r.달력남았나, '여기도 옛 달력은 없다');
  ok(r.값 === '2008-01-20', "고른 값이 '2008-01-20' 으로 나온다 (지금: " + r.값 + ')');
  await pg.close();
}

await b.close();
done();
})();
