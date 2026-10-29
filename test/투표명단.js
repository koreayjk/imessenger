// 📋 투표 — 선택지별로 누가 골랐는지
const { launch, openApp, ok, done } = require('./_harness');

const mkPoll = (anon, closed) => `(async () => {
  const meta = { type:'poll', q:'간식 뭐 살까요?', opts:['과자','아이스크림','둘 다'],
                 multi:false, anon:${anon}, addOn:false, deadline:null, closed:${closed} };
  const m = { id:'p9', channel_id:'ch2', sender_id:'me', sender_name:'김선생',
              text: JSON.stringify(meta), kind:'poll', created_at:new Date().toISOString() };
  pollMsgCache['p9'] = m;
  pollVotesByMsg['p9'] = [
    { message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' },
    { message_id:'p9', option_index:0, member_id:'s2', member_name:'김하은' },
    { message_id:'p9', option_index:1, member_id:'s3', member_name:'이준서' },
  ];
  pollOptsByMsg['p9'] = [];
  return 'ok';
})()`;

(async () => {
const b = await launch();

console.log('\n① 끝난 투표에서 명단을 연다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mkPoll(false, true));
  const r = await pg.evaluate(`(() => {
    showPollVoters('p9');
    const el = document.querySelector('.poll-voters-modal');
    return { open: !!el, txt: el ? el.innerText : '' };
  })()`);
  ok(r.open, '명단 창이 열린다');
  ok(/과자/.test(r.txt) && /아이스크림/.test(r.txt) && /둘 다/.test(r.txt), '선택지가 모두 나온다');
  ok(/홍길동/.test(r.txt) && /김하은/.test(r.txt), '과자를 고른 두 사람 이름이 나온다');
  ok(/이준서/.test(r.txt), '아이스크림을 고른 사람도 나온다');
  ok(/아직 아무도 고르지 않았어요/.test(r.txt), '아무도 안 고른 선택지는 그렇다고 적는다');
  ok(/참여 3명/.test(r.txt), '모두 몇 명이 참여했는지 나온다');
  ok(/마감됨/.test(r.txt), '끝난 투표라고 적혀 있다');
  await pg.close(); }

console.log('\n② 익명 투표는 절대 열리지 않는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mkPoll(true, true));
  const r = await pg.evaluate(`(() => {
    showPollVoters('p9');
    return { open: !!document.querySelector('.poll-voters-modal'), body: document.body.innerText };
  })()`);
  ok(!r.open, '익명이면 창이 안 열린다');
  ok(/익명 투표라/.test(r.body), '왜 못 보는지 말해 준다');
  await pg.close(); }

console.log('\n③ 선택지 하나만 볼 수도 있다 (아바타 줄 누르기)');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mkPoll(false, false));
  const r = await pg.evaluate(`(() => {
    showPollVoters('p9', 'i1');
    const el = document.querySelector('.poll-voters-modal');
    return el.innerText;
  })()`);
  ok(/아이스크림/.test(r) && /이준서/.test(r), '고른 선택지의 명단이 나온다');
  ok(!/홍길동/.test(r), '다른 선택지 사람은 안 섞인다');
  await pg.close(); }

console.log('\n④ 투표 카드에 명단으로 가는 길이 있다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(`(async () => {
    const meta = { type:'poll', q:'간식 뭐 살까요?', opts:['과자','아이스크림','둘 다'],
                   multi:false, anon:false, addOn:false, deadline:null, closed:true };
    const m = { id:'p9', channel_id:'ch2', sender_id:'me', sender_name:'김선생',
                text: JSON.stringify(meta), kind:'poll', created_at:new Date().toISOString() };
    pollMsgCache['p9'] = m; pollOptsByMsg['p9'] = [];
    pollVotesByMsg['p9'] = [
      { message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' },
      { message_id:'p9', option_index:1, member_id:'s3', member_name:'이준서' }];
    const html = renderPollCard(m);
    const anonHtml = renderPollCard({ ...m, text: JSON.stringify({ ...meta, anon:true }) });
    return { html, anonHtml };
  })()`);
  ok(/showPollVoters\('p9'\)/.test(r.html), "아래에 '📋 명단' 으로 가는 길이 있다");
  ok(/showPollVoters\('p9','i0'\)/.test(r.html), '아바타 줄을 눌러도 그 선택지 명단이 열린다');
  ok(!/showPollVoters/.test(r.anonHtml), '익명 투표 카드에는 그 길이 아예 없다');
  await pg.close(); }

await b.close();
done();
})();
