//  ✍️ 활동 후기 — 분류 「＋ 직접 입력」 이 안 열리던 것
//
//    "직접입력 분류 그리고 이 메뉴가 안되고
//     그래서 기입을 했는데 저장이 안되네요"
//
//  재 보니 운영 DB 의 **17개 공동체 중 14곳에 분류가 하나도 없었습니다.**
//  그러면 고르개에 「＋ 직접 입력」 한 개만 들어가고, 브라우저가 그걸
//  처음부터 고른 상태로 그립니다. 값이 안 바뀌니 onchange 가 안 울리고,
//  분류를 적는 칸은 숨은 채로 남습니다 — 눌러도 아무 일이 없습니다.
//  그래서 분류가 비고, 저장할 때 "분류를 선택하거나 입력하세요" 에서 막힙니다.
//
//  ★ 여기서 재는 것
//   ① 분류가 하나도 없는 공동체에서 적는 칸이 처음부터 보이나
//   ② 분류가 있으면 평소대로 숨어 있나 (괜히 늘 보이면 안 된다)
//   ③ 「＋ 직접 입력」 을 고르면 열리나
//   ④ 적은 분류가 그대로 저장되나
//   ⑤ 안 적고 저장하면 조용히 실패하지 않고 알려주나
const { launch, openApp, ok, done } = require('./_harness');

const CATS = [
  { id:'c-1', community_id:'c1', name:'봉사', sort:10 },
  { id:'c-2', community_id:'c1', name:'진로', sort:20 },
];

async function openWriting(b, o = {}) {
  const pg = await openApp(b, { as:'student' });
  await pg.evaluate((d) => {
    ME.community_id = 'c1'; ME.id = 's1'; ME.name = '홍길동';
    writingKind = 'activity';
    reviewCats = (d.cats || []).map(x => Object.assign({}, x));
    reviewCatCustom = false;
    writingEntries = (d.entries || []).map(x => Object.assign({}, x));
    actEditId = d.editId || null;
    window.__DB.student_writings = [];
    window.__DB.review_categories = (d.cats || []).map(x => Object.assign({}, x));
    document.getElementById('writing-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="writing-main"></div>');
    renderWriting();
  }, o);
  return pg;
}
const READ = `() => {
  const sel = document.getElementById('wr-cat');
  const cst = document.getElementById('wr-cat-custom');
  return {
    opts: [...sel.options].map(o => o.value),
    value: sel.value,
    shown: !!cst && cst.style.display !== 'none',
    selShown: sel.style.display !== 'none',
    custVal: cst ? cst.value : null,
  };
}`;

(async () => {
const b = await launch();

// ── ① 분류가 하나도 없는 공동체 ─────────────────────────────
console.log('\n① 분류가 하나도 없을 때 — 운영 17곳 중 14곳이 이 상태입니다');
{
  const pg = await openWriting(b, { cats: [] });
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.opts.join(',') === '__custom__', '고르개에 「＋ 직접 입력」 하나뿐이다');
  ok(r.value === '__custom__', '그게 처음부터 골라져 있다 (그래서 onchange 가 안 울린다)');
  ok(r.shown, '★ 분류 적는 칸이 처음부터 보인다 ← 전에는 숨어 있어서 아무것도 못 했다');
  ok(!r.selShown, '고를 것이 없는 고르개는 숨긴다 ← 눌러도 아무 일이 없어 "메뉴가 안 된다" 가 된다');
}

// ── ② 분류가 있을 때는 평소대로 ────────────────────────────
console.log('\n② 분류가 있을 때는 숨어 있다');
{
  const pg = await openWriting(b, { cats: CATS });
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.opts.join(',') === '봉사,진로,__custom__', '분류 두 개 + 직접 입력');
  ok(r.value === '봉사', '첫 분류가 골라져 있다');
  ok(!r.shown, '적는 칸은 숨어 있다 (괜히 늘 보이면 안 된다)');
  ok(r.selShown, '고르개는 보인다');
}

// ── ③ 「＋ 직접 입력」 을 고르면 열린다 ────────────────────
console.log('\n③ 골라서 열기');
{
  const pg = await openWriting(b, { cats: CATS });
  const r = await pg.evaluate(() => {
    const sel = document.getElementById('wr-cat');
    sel.value = '__custom__'; onReviewCatChange(sel.value);
    const on = document.getElementById('wr-cat-custom').style.display !== 'none';
    sel.value = '봉사'; onReviewCatChange(sel.value);
    const off = document.getElementById('wr-cat-custom').style.display !== 'none';
    return { on, off };
  });
  await pg.close();
  ok(r.on, '고르면 열린다');
  ok(!r.off, '다시 분류로 돌리면 닫힌다');
}

// ── ③-2 다시 그려도 고른 상태가 남는다 ────────────────────
//  화면이 다시 그려졌을 때 고르개는 첫 분류로 돌아가는데 적는 칸만 열려
//  있으면, 적은 글은 버려지고 **엉뚱한 분류로** 저장됩니다.
console.log('\n③-2 다시 그려도 고른 상태가 남는다');
{
  const pg = await openWriting(b, { cats: CATS });
  const r = await pg.evaluate(() => {
    const sel = document.getElementById('wr-cat');
    sel.value = '__custom__'; onReviewCatChange(sel.value);
    renderWriting();                      // 뭔가로 다시 그려졌다
    const s2 = document.getElementById('wr-cat');
    const c2 = document.getElementById('wr-cat-custom');
    return { value: s2.value, shown: c2.style.display !== 'none' };
  });
  await pg.close();
  ok(r.value === '__custom__', '다시 그려도 「직접 입력」 이 골라진 채로 남는다 (' + r.value + ')');
  ok(r.shown, '적는 칸도 열린 채로 남는다');
}

// ── ④ 적은 분류가 그대로 저장된다 ──────────────────────────
console.log('\n④ 저장');
{
  const pg = await openWriting(b, { cats: [] });
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    window.initWritingPage = async () => {};        // 다시 불러오기는 건너뛴다
    document.getElementById('wr-cat-custom').value = '  삼성 임직원 토크쇼  ';
    document.getElementById('wr-title').value = '삼성 임직원 토크쇼';
    document.getElementById('wr-' + ACT_QS[0].key).value = '재미있었습니다.';
    const before = window.__ins.length;
    await addWriting();
    const row = (window.__ins[before] || { rows:[{}] }).rows[0];
    return { said, cat: row.category, title: row.title, kind: row.kind, body: row.body };
  });
  await pg.close();
  ok(r.cat === '삼성 임직원 토크쇼', '적은 분류가 앞뒤 공백 없이 들어간다 (' + JSON.stringify(r.cat) + ')');
  ok(r.title === '삼성 임직원 토크쇼' && r.kind === 'activity', '제목·종류도 같이 들어간다');
  ok(/저장됐어요/.test(r.said), '저장했다고 알려준다');
}

// ── ⑤ 안 적고 저장하면 알려준다 ────────────────────────────
console.log('\n⑤ 비워 두고 저장');
{
  const pg = await openWriting(b, { cats: [] });
  const r = await pg.evaluate(async () => {
    let said = '';
    window.showUploadToast = (m) => { said += m + '|'; };
    window.initWritingPage = async () => {};
    document.getElementById('wr-title').value = '제목만 적음';
    const before = window.__ins.length;
    await addWriting();
    return { said, sent: window.__ins.length - before };
  });
  await pg.close();
  ok(r.sent === 0, '아무것도 안 보낸다');
  ok(/분류를 선택하거나 입력하세요/.test(r.said), '왜 안 되는지 말해준다');
  ok(!/저장됐어요/.test(r.said), "'저장됐어요' 라고 거짓말하지 않는다");
}

// ── ⑥ 고치기 — 목록에 없는 분류로 쓴 글 ───────────────────
console.log('\n⑥ 고치기');
{
  const pg = await openWriting(b, {
    cats: CATS, editId: 'w1',
    entries: [{ id:'w1', kind:'activity', category:'삼성 임직원 토크쇼',
                title:'토크쇼', body:'본문', date:'2026-11-11', member_id:'s1' }],
  });
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.value === '__custom__', '목록에 없는 분류면 「직접 입력」 으로 열린다');
  ok(r.shown, '적는 칸이 보인다');
  ok(r.custVal === '삼성 임직원 토크쇼', '쓰던 분류가 그대로 들어있다');
}

await b.close();
done();
})();
