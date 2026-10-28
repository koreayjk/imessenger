// 🚫 학비 현황판 — 대상이 아닌 사람 끄기
const { launch, openApp, ok, done } = require('./_harness');

//  같은 그룹 안에 내는 사람과 안 내는 사람을 섞어 둔다
const seed = (exempt) => `(async () => {
  tcsGroups = [{ id:'g1', name:'리뉴젠' }, { id:'g2', name:'인투젠' }];
  schoolStudents = [
    { id:'a', name:'가학생', group_id:'g1', tuition_monthly:300, tuition_exempt:false },
    { id:'b', name:'나학생', group_id:'g1', tuition_monthly:300, tuition_exempt:${exempt} },
    { id:'c', name:'다학생', group_id:'g2', tuition_monthly:300, tuition_exempt:false },
  ];
  window.__DB.members = schoolStudents.map(x => ({ ...x, community_id:'c1' }));
  tuiBills = []; tuiCur = '원'; tuiYear = new Date().getFullYear();
  tuiGroups = new Set(); tuiShowExempt = false;
  schoolSubMode = 'tuition'; finTab = 'tuition';
  renderTuition();
  await new Promise(r => setTimeout(r, 250));
})()`;

const read = `(() => {
  const m = document.getElementById('school-main');
  const names = [...m.querySelectorAll('tbody tr td:first-child')].map(x => x.innerText.replace(/\\s+/g, ' ').trim());
  return { txt: m.innerText, names,
           arrears: (m.innerText.match(/누적 미납[\\s\\S]{0,60}?(\\d+)명/) || [])[1] || null };
})()`;

(async () => {
const b = await launch();

console.log('\n① 아무도 안 뺐을 때');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(false));
  const r = await pg.evaluate(read);
  ok(r.names.filter(n => /학생/.test(n)).length === 3, '세 명이 다 보인다');
  ok(!/대상 아님/.test(r.txt), "'대상 아님' 칩이 뜨지 않는다 — 뺀 사람이 없으니까");
  ok(r.arrears === '3', '미납 인원이 3명으로 잡힌다');
  await pg.close(); }

console.log('\n② 한 명을 빼면');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(true));
  const r = await pg.evaluate(read);
  ok(!r.names.some(n => /나학생/.test(n)), '뺀 사람은 표에서 사라진다');
  ok(r.names.some(n => /가학생/.test(n)) && r.names.some(n => /다학생/.test(n)), '나머지는 그대로 보인다');
  ok(/대상 아님 1명/.test(r.txt), "'대상 아님 1명' 칩이 생긴다");
  ok(r.arrears === '2', '미납 인원이 2명으로 줄어든다 — 계산에서도 빠진다');
  await pg.close(); }

console.log('\n③ 칩을 누르면 다시 보인다 (언제든 켰다 껐다)');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(true));
  const r = await pg.evaluate(`(async () => {
    tuiToggleShowExempt();
    await new Promise(r => setTimeout(r, 200));
    const m = document.getElementById('school-main');
    const row = [...m.querySelectorAll('tbody tr')].find(tr => /나학생/.test(tr.innerText));
    return { txt: m.innerText,
             shown: !!row,
             mark: row ? /대상 아님/.test(row.innerText) : false,
             back: row ? !!row.querySelector('button[onclick*="toggleTuiExempt"]') : false,
             arrears: (m.innerText.match(/누적 미납[\\s\\S]{0,60}?(\\d+)명/) || [])[1] || null };
  })()`);
  ok(r.shown, '칩을 누르면 뺀 사람도 줄에 나온다');
  ok(r.mark, "그 줄에 '대상 아님' 이라고 적혀 있다");
  ok(r.back, '되돌리는 단추가 그 줄에 있다');
  ok(r.arrears === '2', '보이기만 할 뿐 미납 계산에는 여전히 안 들어간다');
  await pg.close(); }

console.log('\n④ 그룹을 골라도 따로 센다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(true));
  const r = await pg.evaluate(`(async () => {
    tuiToggleGroup('g2');                       // 인투젠만 — 뺀 사람은 리뉴젠에 있다
    await new Promise(r => setTimeout(r, 250));
    const a = document.getElementById('school-main').innerText;
    tuiGroups = new Set(['g1']); renderTuition();
    await new Promise(r => setTimeout(r, 250));
    return { g2: a, g1: document.getElementById('school-main').innerText };
  })()`);
  ok(!/대상 아님/.test(r.g2), '인투젠만 보면 칩이 없다 — 그 그룹에는 뺀 사람이 없으니까');
  ok(/대상 아님 1명/.test(r.g1), '리뉴젠을 보면 1명이라고 나온다');
  await pg.close(); }

console.log('\n⑤ DB 설치 전에는 그렇다고 말한다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(false));
  const r = await pg.evaluate(`(async () => {
    window.__err = { table:'members', e:{ code:'42703', message:'column members.tuition_exempt does not exist' } };
    await toggleTuiExempt('a');
    await new Promise(r => setTimeout(r, 200));
    return { body: document.body.innerText, still: schoolStudents.find(x => x.id === 'a').tuition_exempt };
  })()`);
  ok(/학비_대상제외_DB설치\.sql/.test(r.body), '무엇을 실행하면 되는지 적어 준다');
  ok(r.still === false, '저장이 안 됐으면 화면에서도 바꾸지 않는다');
  await pg.close(); }

console.log('\n⑥ 종이(PDF)에는 늘 대상자만');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(seed(true));
  const r = await pg.evaluate(`(async () => {
    tuiToggleShowExempt();                      // 화면에는 보이게 켜 둔다
    await new Promise(r => setTimeout(r, 200));
    let html = '';
    const real = window.openPrintDoc;
    window.openPrintDoc = (o) => { html = (o.bodyHtml || o.html || JSON.stringify(o)); };
    printTuitionMatrix();
    window.openPrintDoc = real;
    return { html, screen: document.getElementById('school-main').innerText };
  })()`);
  ok(/나학생/.test(r.screen), '화면에는 (켜 뒀으니) 보인다');
  ok(!/나학생/.test(r.html), '그래도 종이에는 안 들어간다 — 보던 방식에 따라 종이가 달라지면 안 된다');
  ok(/가학생/.test(r.html) && /다학생/.test(r.html), '대상자는 종이에 그대로 들어간다');
  await pg.close(); }

await b.close();
done();
})();
