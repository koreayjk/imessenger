//  ↑ 이전 글 더 보기 (개선창 · 박유빈)
//
//    "좀 챗이 많거나 하면 그 전에 봣던 것들을 다시 보는 데에 좀 제한이
//     있네요.. 혹시 범위를 좀만 더 늘려주실 수 있을까요?"
//
//  최신 200개만 불러오고 끝이었습니다. 숫자만 키우면 글이 많은 방은
//  열리는 데만 한참 걸립니다. 맨 위에서 한 묶음씩 더 가져옵니다.
//
//  ⚠️ 위에 글을 끼워 넣으면 보던 자리가 아래로 밀립니다. 그만큼 다시
//     내려 줘야 읽던 자리에 머뭅니다.
const { launch, openApp, ok, done } = require('./_harness');

//  n개의 글을 만든다 (오래된 것부터)
function msgs(chId, n, from = 0) {
  return Array.from({ length: n }, (_, i) => ({
    id: 'm' + (from + i),
    channel_id: chId,
    sender_id: 'me', sender_name: '김선생',
    text: '글 ' + (from + i),
    created_at: new Date(Date.UTC(2026, 0, 1) + (from + i) * 60000).toISOString(),
  }));
}

//  ⚠️ 창 크기와 setMode('chat') 이 없으면 글 칸의 높이가 0 이라
//     '읽던 자리' 를 아예 잴 수 없다 (0 → 0 으로 거짓 통과했다).
async function openCh(b, total) {
  const pg = await openApp(b, { as:'teacher', viewport:{ width:1280, height:800 } });
  await pg.evaluate(async (n) => {
    setMode('chat');
    const ch = channels[0];
    window.__ALL = Array.from({ length: n }, (_, i) => ({
      id: 'm' + i, channel_id: ch.id, sender_id: 'me', sender_name: '김선생',
      text: '글 ' + i,
      created_at: new Date(Date.UTC(2026, 0, 1) + i * 60000).toISOString(),
    }));
    window.__DB.messages = window.__ALL;
    window.__DB.message_reactions = [];
    window.__DB.message_reads = [];
    await openChannel(ch.id);
    await new Promise(r => setTimeout(r, 400));
  }, total);
  return pg;
}
const READ = `() => {
  const area = document.getElementById('msg-area');
  const rows = [...area.querySelectorAll('.msg-row')];
  const texts = rows.map(r => (r.innerText.match(/글 \\d+/) || [''])[0]).filter(Boolean);
  return {
    n: rows.length,
    first: texts[0] || '', last: texts[texts.length-1] || '',
    bar: !!document.getElementById('msg-older-bar'),
    btn: !!document.getElementById('msg-older-btn'),
    barTxt: (document.getElementById('msg-older-bar') || {}).textContent || '',
    maybe: olderMaybe,
  };
}`;

(async () => {
const b = await launch();

// ── ① 글이 적으면 단추가 없다 ───────────────────────────────
console.log('\n① 글이 적을 때');
{
  const pg = await openCh(b, 30);
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.n === 30, '서른 개가 다 나온다');
  ok(r.bar && !r.btn, '단추 대신 띠만 있다');
  ok(/맨 처음이에요/.test(r.barTxt), "'대화의 맨 처음이에요' 라고 알려준다");
  ok(r.maybe === false, '더 있을 것이 없다고 본다');
}

// ── ② 글이 많으면 단추가 생긴다 ─────────────────────────────
console.log('\n② 글이 많을 때');
{
  const pg = await openCh(b, 520);
  const r = await pg.evaluate(eval(READ));
  await pg.close();
  ok(r.n === 200, '처음에는 200개만 불러온다 (열기가 빨라야 한다)');
  ok(r.last === '글 519', '제일 최신 글이 맨 아래다');
  ok(r.first === '글 320', '200개째부터 보인다');
  ok(r.btn, '맨 위에 [이전 글 더 보기] 가 있다 ← 이게 요청이었다');
  ok(r.maybe === true, '더 있을 수 있다고 본다');
}

// ── ③ 눌러서 더 가져온다 ────────────────────────────────────
console.log('\n③ 더 가져오기');
{
  const pg = await openCh(b, 520);
  const r = await pg.evaluate(async (rd) => {
    const out = { steps: [] };
    const area = document.getElementById('msg-area');
    area.scrollTop = 0;
    await loadOlderMessages();
    await new Promise(r2 => setTimeout(r2, 300));
    out.steps.push(eval(rd)());
    await loadOlderMessages();
    await new Promise(r2 => setTimeout(r2, 300));
    out.steps.push(eval(rd)());
    await loadOlderMessages();          // 이제 더 없다
    await new Promise(r2 => setTimeout(r2, 300));
    out.steps.push(eval(rd)());
    return out;
  }, READ);
  await pg.close();
  const [a, c, d] = r.steps;
  console.log('       ' + r.steps.map(x => x.n + '개(' + x.first + '…' + x.last + ')').join(' → '));
  ok(a.n === 400 && a.first === '글 120', '한 번 누르면 200개가 더 붙는다');
  ok(a.last === '글 519', '맨 아래는 그대로 최신 글이다');
  ok(c.n === 520 && c.first === '글 0', '두 번 누르면 맨 처음까지 온다');
  ok(!c.btn && /맨 처음이에요/.test(c.barTxt),
     '다 가져오면 단추가 사라지고 맨 처음이라고 알려준다');
  ok(d.n === 520, '더 눌러도 같은 글이 두 번 붙지 않는다');
}

// ── ④ 읽던 자리에 머문다 ────────────────────────────────────
console.log('\n④ 읽던 자리');
{
  const pg = await openCh(b, 520);
  const r = await pg.evaluate(async () => {
    const area = document.getElementById('msg-area');
    //  맨 위로 올라가서 보던 글을 하나 정한다
    area.scrollTop = 0;
    const mark = area.querySelector('[data-id="m330"]');
    const beforeTop = mark ? mark.getBoundingClientRect().top : null;
    const beforeH = area.scrollHeight;
    await loadOlderMessages();
    await new Promise(r2 => setTimeout(r2, 300));
    const mark2 = area.querySelector('[data-id="m330"]');
    return {
      beforeTop, afterTop: mark2 ? mark2.getBoundingClientRect().top : null,
      grew: area.scrollHeight > beforeH,
      boxH: area.clientHeight, beforeH, afterH: area.scrollHeight,
    };
  });
  await pg.close();
  console.log(`       칸 높이 ${r.boxH} · 길이 ${r.beforeH} → ${r.afterH}`);
  ok(r.boxH > 100, '글 칸에 높이가 있다 ← 0 이면 아무것도 잴 수 없다');
  ok(r.grew, '글이 더 붙어서 길이가 늘었다');
  ok(r.beforeTop !== null && r.afterTop !== null, '보던 글을 앞뒤로 찾았다');
  ok(Math.abs(r.afterTop - r.beforeTop) <= 3,
     `보던 글이 제자리에 있다 (${Math.round(r.beforeTop)} → ${Math.round(r.afterTop)}) ← 안 맞추면 읽던 자리를 잃는다`);
}

await b.close();
done();
})();
