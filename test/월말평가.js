//  📅 월말평가 — 학기 성적과 따로 적는 칸
//
//  개선창에 같은 요청이 둘 올라왔습니다 (IM HQ, 11/20):
//   · 양회광 「리뉴젠아카데미는 분기별 월말평가도있는데 그것도 기록
//            할 수 있게끔 하면 좋겠습니다!」
//   · 홍예원 「리뉴젠 아이들은 월말평기를 보는데 달마다 작성할 수
//            있게 해주셨으면 좋겠습니다」
//
//  ⚠️ 쉬운 길은 학기 칸(sem)에 1~12월을 넣는 것입니다. 그러면 안 됩니다 —
//     그 칸은 생기부 별지 제7·9·11호 출력이 「1학기/2학기」 로 읽습니다.
//     월을 넣으면 양식이 깨집니다. 선교사님과 상의해 **칸을 따로** 두기로
//     했습니다 (2026-11-25).
//
//  저장도 같은 academic 칸 안의 딴 열쇠에 넣습니다 —
//     g7_grades  : 학기 성적 (별지가 읽는 것)
//     g7_monthly : 월말평가 (별지가 안 읽는 것)
//
//  재는 것:
//   ① 학기 칸은 그대로 1·2 만 (월이 섞이지 않았다)
//   ② 월말평가 칸이 따로 있고 1~12월을 고른다
//   ③ 적으면 <학년>_monthly 로 저장된다
//   ④ 학기 성적(<학년>_grades)은 안 건드린다 ← 가장 중요한 것
//   ⑤ 학년을 바꾸면 그 학년 월말평가로 바뀐다
//   ⑥ 저장된 것을 다시 열면 그대로 보인다
//   ⑦ 빈 줄만 있으면 아무것도 저장하지 않는다 · 마지막 줄은 남는다
const { launch, openApp, ok, done } = require('./_harness');

async function openAcad(b, saved) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate((sv) => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1';
    tcsCurrentStudent = { id:'st1', name:'홍길동', grade:'G7' };
    tcsRecords = { academic: JSON.parse(JSON.stringify(sv || {})) };
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    //  에디터가 그리는 자리
    if (!document.getElementById(tcsMainId))
      document.body.insertAdjacentHTML('beforeend', `<div id="${tcsMainId}"></div>`);
    openAcademicEditor();
  }, saved || {});
  await pg.waitForTimeout(400);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 학기 칸은 그대로 ─────────────────────────────────────
console.log('\n① 학기 칸');
{
  const pg = await openAcad(b, {});
  const r = await pg.evaluate(() => ({
    sem: TCS_ACAD_FIELDS.sem.options.slice(),
    monthsInSem: TCS_ACAD_FIELDS.sem.options.filter(o => Number(o) > 2),
    mon: TCS_MON_FIELDS.month.options.slice(),
  }));
  ok(r.sem.join(',') === '1,2', '학기 칸은 1·2 만 그대로다 ← 별지 양식이 이걸 읽는다', r.sem.join(','));
  ok(r.monthsInSem.length === 0, '학기 칸에 월을 섞지 않았다', r.monthsInSem.join(','));
  ok(r.mon.length === 12 && r.mon[0] === '1' && r.mon[11] === '12',
     '월말평가 칸은 1~12월을 고른다', r.mon.join(','));
  await pg.close();
}

// ── ② 화면에 따로 있나 ─────────────────────────────────────
console.log('\n② 월말평가 칸이 따로');
{
  const pg = await openAcad(b, {});
  const r = await pg.evaluate(() => {
    const box = document.getElementById('acad-monthly');
    const sel = document.querySelector('#acad-mon-rows select');
    return {
      card: !!box,
      says: box ? /학기 성적과는 따로/.test(box.innerText) : false,
      notInPrint: box ? /별지 출력에는 들어가지 않습니다/.test(box.innerText) : false,
      rows: document.querySelectorAll('#acad-mon-rows > div').length,
      opts: sel ? [...sel.options].map(o => o.value).filter(Boolean).length : 0,
      addBtn: !!document.querySelector('[onclick="addMonthlyRow()"]'),
      sepFromGrades: !!document.getElementById('acad-rows'),
    };
  });
  ok(r.card, '📅 월말평가 카드가 있다');
  ok(r.sepFromGrades, '학기 성적 칸도 그대로 있다');
  ok(r.says, '학기 성적과 따로라고 적어 둔다');
  ok(r.notInPrint, '별지 출력에 안 들어간다고 알려 준다');
  ok(r.rows === 1, '처음엔 빈 줄 하나로 시작한다', r.rows);
  ok(r.opts === 12, '그 줄에서 열두 달을 고른다', r.opts);
  ok(r.addBtn, '줄을 더 넣는 단추가 있다');
  await pg.close();
}

// ── ③④ 적어서 저장 ────────────────────────────────────────
console.log('\n③ 적어서 저장하면');
{
  const pg = await openAcad(b, {});
  const r = await pg.evaluate(async () => {
    //  학기 성적 한 줄
    setAcademicField(0, 'sem', '1');
    setAcademicField(0, 'name', '성경');
    setAcademicField(0, 'score', '90');
    //  월말평가 두 줄
    setMonthlyField(0, 'month', '9');
    setMonthlyField(0, 'name', '영어');
    setMonthlyField(0, 'score', '88');
    setMonthlyField(0, 'note', '많이 올랐어요');
    addMonthlyRow();
    setMonthlyField(1, 'month', '10');
    setMonthlyField(1, 'name', '영어');
    setMonthlyField(1, 'score', '92');
    await saveAcademicSection();
    await new Promise(r => setTimeout(r, 500));
    const ups = (window.__ins || []).concat(window.__upd || [])
      .filter(x => x.t === 'tcs_records');
    const rows = (window.__DB['tcs_records'] || []);
    const rec = rows.find(x => x.section === 'academic') || {};
    const d = rec.data || {};
    return { keys: Object.keys(d).sort(),
             monthly: d.g7_monthly ? JSON.parse(d.g7_monthly) : null,
             grades:  d.g7_grades  ? JSON.parse(d.g7_grades)  : null,
             toast: window.__toast.join('|') };
  });
  ok(r.monthly && r.monthly.length === 2, 'g7_monthly 에 두 줄이 저장된다',
     JSON.stringify(r.monthly));
  ok(r.monthly && r.monthly[0].month === '9' && r.monthly[0].score === '88',
     '9월 88점이 그대로 들어간다', JSON.stringify(r.monthly && r.monthly[0]));
  ok(r.monthly && r.monthly[0].note === '많이 올랐어요', '비고도 들어간다',
     r.monthly && r.monthly[0].note);
  ok(r.monthly && r.monthly[1].month === '10', '10월 줄도 따로 들어간다',
     JSON.stringify(r.monthly && r.monthly[1]));

  console.log('\n④ 학기 성적은 안 건드린다');
  ok(r.grades && r.grades.length >= 1, 'g7_grades 도 그대로 저장된다', r.grades && r.grades.length);
  ok(r.grades && r.grades.some(x => x.name === '성경' && x.sem === '1'),
     '학기 성적에 1학기 성경이 그대로 있다', JSON.stringify(r.grades && r.grades[0]));
  ok(r.grades && !r.grades.some(x => Number(x.sem) > 2),
     '학기 성적 어디에도 월이 섞이지 않았다 ← 별지 양식이 안 깨진다',
     JSON.stringify((r.grades||[]).map(x => x.sem)));
  ok(r.keys.includes('g7_monthly') && r.keys.includes('g7_grades'),
     '두 열쇠가 따로 저장된다', r.keys.join(','));
  await pg.close();
}

// ── ⑤ 학년을 바꾸면 ────────────────────────────────────────
console.log('\n⑤ 학년을 바꿀 때');
{
  const pg = await openAcad(b, {
    g7_monthly: JSON.stringify([{ month:'9', name:'영어', score:'88', note:'' }]),
    g8_monthly: JSON.stringify([{ month:'3', name:'수학', score:'70', note:'' }]),
  });
  const r = await pg.evaluate(async () => {
    const g7 = document.getElementById('acad-mon-rows').innerHTML;
    switchAcademicGrade('g8_grades');
    await new Promise(r => setTimeout(r, 300));
    const g8 = document.getElementById('acad-mon-rows').innerHTML;
    return { g7has: /영어/.test(g7), g7no: /수학/.test(g7),
             g8has: /수학/.test(g8), g8no: /영어/.test(g8) };
  });
  ok(r.g7has && !r.g7no, 'G7 에서는 G7 월말평가만 보인다', `영어 ${r.g7has} · 수학 ${r.g7no}`);
  ok(r.g8has && !r.g8no, 'G8 로 바꾸면 G8 것으로 바뀐다', `수학 ${r.g8has} · 영어 ${r.g8no}`);
  await pg.close();
}

// ── ⑥ 다시 열면 그대로 ─────────────────────────────────────
console.log('\n⑥ 저장된 것을 다시 열면');
{
  const pg = await openAcad(b, {
    g7_grades:  JSON.stringify([{ sem:'1', name:'성경', score:'90' }]),
    g7_monthly: JSON.stringify([{ month:'11', name:'국어', score:'95', note:'잘했어요' }]),
  });
  const r = await pg.evaluate(() => {
    const mon = document.getElementById('acad-mon-rows');
    const picked = mon.querySelector('select').value;
    return { txt: mon.innerHTML, picked,
             avg: document.getElementById('acad-mon-avg').textContent,
             gradeTxt: document.getElementById('acad-rows').innerHTML };
  });
  ok(/국어/.test(r.txt) && /95/.test(r.txt), '적어 둔 월말평가가 그대로 보인다');
  ok(r.picked === '11', '고른 달(11월)도 그대로다', r.picked);
  ok(/잘했어요/.test(r.txt), '비고도 그대로다');
  ok(/95/.test(r.avg) || /1건/.test(r.avg), '요약에 건수·평균이 나온다', r.avg);
  ok(/성경/.test(r.gradeTxt), '학기 성적도 그대로 보인다');
  await pg.close();
}

// ── ⑦ 빈 줄 · 마지막 줄 ────────────────────────────────────
console.log('\n⑦ 빈 줄일 때');
{
  const pg = await openAcad(b, {});
  const r = await pg.evaluate(async () => {
    await saveAcademicSection();
    await new Promise(r => setTimeout(r, 400));
    const rec = (window.__DB['tcs_records'] || []).find(x => x.section === 'academic') || {};
    const saved = (rec.data || {}).g7_monthly;
    return { saved: saved == null ? '(없음)' : saved };
  });
  ok(r.saved === '(없음)', '빈 줄만 있으면 아무것도 저장하지 않는다', r.saved);
  await pg.close();
}

// ── ⑦-2 마지막 줄을 지울 때 ────────────────────────────────
//   ⚠️ 저장하면 목록으로 돌아가 #acad-mon-rows 가 사라집니다.
//      그래서 저장과 따로 재야 합니다 (여기서 한 번 틀렸습니다).
console.log('\n⑦-2 마지막 줄을 지우면');
{
  const pg = await openAcad(b, {
    g7_monthly: JSON.stringify([{ month:'9', name:'영어', score:'88', note:'' }]),
  });
  const r = await pg.evaluate(() => {
    const before = document.querySelectorAll('#acad-mon-rows > div').length;
    removeMonthlyRow(0);
    const after = document.querySelectorAll('#acad-mon-rows > div').length;
    const rows = tcsAcademicDraft.monthly['g7_grades'];
    return { before, after, kept: rows.length,
             empty: rows.length === 1 && !rows[0].name && !rows[0].score,
             txt: document.getElementById('acad-mon-rows').innerHTML };
  });
  ok(r.before === 1, '지우기 전에 한 줄 있다', r.before);
  ok(r.after === 1,  '지운 뒤에도 적을 칸 하나는 남는다', r.after);
  ok(r.empty,        '그 줄은 비어 있다 (지운 것이 되살아나지 않는다)', JSON.stringify(r.kept));
  ok(!/영어/.test(r.txt), '지운 내용은 사라졌다');
  await pg.close();
}

await b.close();
done();
})();
