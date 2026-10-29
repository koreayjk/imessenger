// 📥 재정 입출금 — 엑셀을 더 올려도 기존 것이 사라지지 않아야 한다
const { launch, openApp, ok, done } = require('./_harness');

//  이미 1월에 두 줄이 들어 있고, 세 줄짜리 파일을 더 올리는 상황.
//  그 중 한 줄(커피)은 이미 있는 것과 똑같다.
const EXISTING = [
  { id:'x1', community_id:'c1', month:'2026-01', tx_date:'2026-01-05', description:'KROGER',  amount:-50.00, category:'Grocery', source:'import' },
  { id:'x2', community_id:'c1', month:'2026-01', tx_date:'2026-01-07', description:'COFFEE',  amount:-5.00,  category:'Eating Out', source:'import' },
];
const FILE = [
  { month:'2026-01', tx_date:'2026-01-07', description:'COFFEE', amount:-5.00,  category:'Eating Out' },
  { month:'2026-01', tx_date:'2026-01-20', description:'SHELL',  amount:-40.00, category:'Fuel (Oil)' },
  { month:'2026-01', tx_date:'2026-01-25', description:'HEB',    amount:-30.00, category:'Grocery' },
];

const prep = `(async () => {
  Object.assign(window.__DB, { finance_transactions: ${JSON.stringify(EXISTING)} });
  ledgerPending = ${JSON.stringify(FILE)};
  const scan = await ledgerScanDuplicates(ledgerPending);
  ledgerShowImportPreview(ledgerPending, scan);
  await new Promise(r => setTimeout(r, 200));
  return scan;
})()`;

const after = `(() => {
  const rows = window.__DB.finance_transactions || [];
  return { n: rows.length, desc: rows.map(r => r.description).sort(),
           body: document.body.innerText };
})()`;

(async () => {
const b = await launch();

console.log('\n① 미리보기 — 겹치는 줄을 세어 알려준다');
{ const pg = await openApp(b, { as:'teacher' });
  const scan = await pg.evaluate(prep);
  const r = await pg.evaluate(`(() => ({
    body: document.querySelector('.ledger-import-modal').innerText,
    mode: (document.querySelector('input[name="lg-mode"]:checked')||{}).value,
  }))()`);
  ok(scan.dup === 1 && scan.add === 2, '파일 3건 중 1건이 이미 있다고 센다');
  ok(/1건은 이미 들어 있어요/.test(r.body), '몇 건이 겹치는지 화면에 적어 준다');
  ok(r.mode === 'add', "기본이 '더하기' 다 — 예전에는 '지우고 넣기' 가 기본이었다");
  await pg.close(); }

console.log('\n② 더하기 — 있던 것이 그대로 남는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(prep);
  await pg.evaluate(`(async () => { await ledgerImport(); await new Promise(r=>setTimeout(r,300)); })()`);
  const r = await pg.evaluate(after);
  ok(r.desc.includes('KROGER'), '1월에 있던 KROGER 가 그대로 있다');
  ok(r.n === 4, '2건 + 새로 2건 = 4건 (겹치는 COFFEE 는 안 들어간다)');
  ok(r.desc.filter(d => d === 'COFFEE').length === 1, 'COFFEE 가 두 줄이 되지 않는다');
  ok(r.desc.includes('SHELL') && r.desc.includes('HEB'), '새 줄은 들어간다');
  ok(/건너뜀 1건/.test(r.body), '몇 건을 건너뛰었는지 결과에 적어 준다');
  await pg.close(); }

console.log('\n③ 지우고 넣기는 묻고 나서 — 취소하면 아무것도 안 한다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(prep);
  const r = await pg.evaluate(`(async () => {
    let asked = '';
    window.confirm = (m) => { asked = m; return false; };     // 사용자가 '취소'
    document.querySelector('input[name="lg-mode"][value="replace"]').checked = true;
    await ledgerImport();
    await new Promise(r => setTimeout(r, 250));
    const rows = window.__DB.finance_transactions || [];
    return { asked, n: rows.length, desc: rows.map(x=>x.description).sort() };
  })()`);
  ok(/지우고/.test(r.asked), '지우기 전에 묻는다');
  ok(/2026-01/.test(r.asked), '어느 달이 지워지는지 말해 준다');
  ok(/더하기/.test(r.asked), "'더하기' 로 가는 길을 알려 준다");
  ok(r.n === 2 && r.desc.includes('KROGER'), '취소하면 한 줄도 건드리지 않는다');
  await pg.close(); }

console.log('\n④ 지우고 넣기를 정말 고르면 그대로 한다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(prep);
  const r = await pg.evaluate(`(async () => {
    window.confirm = () => true;
    document.querySelector('input[name="lg-mode"][value="replace"]').checked = true;
    await ledgerImport();
    await new Promise(r => setTimeout(r, 300));
    const rows = window.__DB.finance_transactions || [];
    return { n: rows.length, desc: rows.map(x=>x.description).sort() };
  })()`);
  ok(r.n === 3, '그 달 업로드분을 지우고 파일 3건만 남는다');
  ok(!r.desc.includes('KROGER'), '고른 대로 KROGER 는 사라진다 — 고를 수는 있어야 한다');
  await pg.close(); }

console.log('\n⑤ 직접 입력한 줄은 지우기에서도 살아남는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(`(async () => {
    Object.assign(window.__DB, { finance_transactions: ${JSON.stringify(EXISTING)}.concat(
      [{ id:'m1', community_id:'c1', month:'2026-01', tx_date:'2026-01-11', description:'직접 적은 것', amount:-9, category:'Misc. Exp.', source:'manual' }]) });
    ledgerPending = ${JSON.stringify(FILE)};
    const scan = await ledgerScanDuplicates(ledgerPending);
    ledgerShowImportPreview(ledgerPending, scan);
    await new Promise(r => setTimeout(r, 200));
    window.confirm = () => true;
    document.querySelector('input[name="lg-mode"][value="replace"]').checked = true;
    await ledgerImport();
    await new Promise(r => setTimeout(r, 300));
  })()`);
  const r = await pg.evaluate(after);
  ok(r.desc.includes('직접 적은 것'), '직접 적은 줄은 그대로 남는다');
  await pg.close(); }

console.log('\n⑥ 같은 날 같은 금액을 두 번 썼으면 두 줄 다 들어간다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(`(async () => {
    Object.assign(window.__DB, { finance_transactions: [
      { id:'y1', community_id:'c1', month:'2026-02', tx_date:'2026-02-03', description:'COFFEE', amount:-5, category:'Eating Out', source:'import' }] });
    ledgerPending = [
      { month:'2026-02', tx_date:'2026-02-03', description:'COFFEE', amount:-5, category:'Eating Out' },
      { month:'2026-02', tx_date:'2026-02-03', description:'COFFEE', amount:-5, category:'Eating Out' }];
    const scan = await ledgerScanDuplicates(ledgerPending);
    ledgerShowImportPreview(ledgerPending, scan);
    await new Promise(r => setTimeout(r, 200));
    await ledgerImport();
    await new Promise(r => setTimeout(r, 300));
    return { scan, n: (window.__DB.finance_transactions||[]).length };
  })()`);
  ok(r.scan.dup === 1 && r.scan.add === 1, '파일의 두 줄 중 하나만 겹친 것으로 센다');
  ok(r.n === 2, '있던 1건 + 더해진 1건 = 2건 — 진짜 두 번 쓴 것은 지워지지 않는다');
  await pg.close(); }

await b.close();
done();
})();
