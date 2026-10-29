// 🎯 투표 — 대상자 지정
const { launch, openApp, ok, done } = require('./_harness');

const mk = (targets, votes) => `(async () => {
  const meta = { type:'poll', q:'간식 뭐 살까요?', opts:['과자','아이스크림'],
                 multi:false, anon:false, addOn:false, targets:${JSON.stringify(targets)},
                 deadline:null, closed:false };
  const m = { id:'p9', channel_id:'ch2', sender_id:'me', sender_name:'김선생',
              text: JSON.stringify(meta), kind:'poll', created_at:new Date().toISOString() };
  pollMsgCache['p9'] = m; pollOptsByMsg['p9'] = [];
  pollVotesByMsg['p9'] = ${JSON.stringify(votes)};
  return renderPollCard(m);
})()`;

(async () => {
const b = await launch();

console.log('\n① 대상자를 안 고르면 예전 그대로');
{ const pg = await openApp(b, { as:'teacher' });
  const html = await pg.evaluate(mk(null, [{ message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' }]));
  ok(/참여 1명/.test(html), "'참여 N명' 으로 보인다");
  ok(!/대상/.test(html), '대상 표시가 없다');
  ok(/votePoll/.test(html), '누구나 고를 수 있다');
  await pg.close(); }

console.log('\n② 대상자를 고르면 — N명 중 M명 완료');
{ const pg = await openApp(b, { as:'teacher' });
  const html = await pg.evaluate(mk(['s1','s2','s3'], [{ message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' }]));
  ok(/대상 3명/.test(html), '대상이 몇 명인지 쪽지로 보인다');
  ok(/3명 중 1명 완료/.test(html), "'3명 중 1명 완료' 로 보인다 — 몇 명이 남았는지 바로 안다");
  await pg.close(); }

console.log('\n③ 대상이 아니면 고를 수 없다');
{ const pg = await openApp(b, { as:'teacher' });
  //  나(me)는 대상이 아니다
  const html = await pg.evaluate(mk(['s1','s2'], []));
  ok(/대상이 아니에요/.test(html), '대상이 아니라고 알려 준다');
  ok(!/votePoll/.test(html), '선택지를 눌러도 아무 일이 없다');
  await pg.close(); }

console.log('\n④ 대상이면 그대로 고른다');
{ const pg = await openApp(b, { as:'student' });   // 나 = s1
  const html = await pg.evaluate(mk(['s1','s2'], []));
  ok(!/대상이 아니에요/.test(html), '대상이면 그런 말이 없다');
  ok(/votePoll/.test(html), '고를 수 있다');
  await pg.close(); }

console.log('\n⑤ 화면만 막으면 샌다 — 손으로 불러도 막는다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mk(['s1','s2'], []));
  const r = await pg.evaluate(`(async () => {
    window.__DB.poll_votes = [];
    await votePoll('p9','i0');                 // 대상이 아닌 내가 손으로 부른다
    await new Promise(r => setTimeout(r, 250));
    return { n: (window.__DB.poll_votes||[]).length, body: document.body.innerText };
  })()`);
  ok(r.n === 0, '표가 들어가지 않는다');
  ok(/대상이 아니에요/.test(r.body), '왜 안 되는지 말해 준다');
  await pg.close(); }

console.log('\n⑥ 명단 창에 아직 안 한 사람이 나온다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mk(['s1','s2','s3'], [{ message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' }]));
  const r = await pg.evaluate(`(() => { showPollVoters('p9');
    return document.querySelector('.poll-voters-modal').innerText; })()`);
  ok(/아직 안 한 사람/.test(r), "'아직 안 한 사람' 칸이 있다");
  ok(/김하은/.test(r) && /이준서/.test(r), '안 한 사람 이름이 나온다');
  ok(/홍길동/.test(r), '한 사람은 고른 선택지 밑에 있다');
  await pg.close(); }

console.log('\n⑦ 다 하면 다 했다고 말한다');
{ const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(mk(['s1','s2'], [
    { message_id:'p9', option_index:0, member_id:'s1', member_name:'홍길동' },
    { message_id:'p9', option_index:1, member_id:'s2', member_name:'김하은' }]));
  const r = await pg.evaluate(`(() => { showPollVoters('p9');
    return document.querySelector('.poll-voters-modal').innerText; })()`);
  ok(/모두 했어요/.test(r), "'모두 했어요' 라고 나온다");
  await pg.close(); }

console.log('\n⑧ 만드는 창에서 고를 수 있다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(`(async () => {
    currentChannel = { id:'ch2', name:'3학년', kind:'topic', community_id:'c1' };
    window.__DB.channel_members = [{ channel_id:'ch2', member_id:'s1' },
                                   { channel_id:'ch2', member_id:'s2' },
                                   { channel_id:'ch2', member_id:'me' }];
    openPollModal();
    const before = document.getElementById('poll-target-sum').textContent;
    await pollPickTargets();
    await new Promise(r => setTimeout(r, 250));
    const boxes = [...document.querySelectorAll('.poll-target')];
    boxes[0].checked = true; pollTargetsChanged();
    return { before, n: boxes.length, after: document.getElementById('poll-target-sum').textContent,
             picked: pollTargets, clr: document.getElementById('poll-target-clear').style.display };
  })()`);
  ok(/이 방 전체/.test(r.before), "처음에는 '이 방 전체' 다 — 안 고르면 예전과 같다");
  ok(r.n === 3, '이 방 멤버가 다 나온다');
  ok(Array.isArray(r.picked) && r.picked.length === 1, '고르면 담긴다');
  ok(/1명/.test(r.after), '몇 명 골랐는지 보인다');
  ok(r.clr !== 'none', "'전체로' 되돌리는 단추가 나타난다");
  await pg.close(); }

await b.close();
done();
})();
