// 👨‍👩‍👧 '내 아이' 에 ＋ 아이 추가 — 선생님 승인 뒤 연결
const { launch, openApp, ok, done } = require('./_harness');

const asParent = `(async () => {
  ME.parent_claim_name = null; ME.parent_claim_birth = null; ME.parent_claim_rel = null;
  members['t2'] = { id:'t2', name:'박교사', community_id:'c1', community_role:'teacher', status:'approved' };
  members['ao'] = { id:'ao', name:'행정샘', community_id:'c1', community_role:'admin_officer', status:'approved' };
  Object.assign(window.__DB, {
    members: Object.values(members).map(m => ({ ...m, community_id:'c1' })),
    student_homerooms: [{ community_id:'c1', student_id:'s1', teacher_id:'t2' }],
    deposit_entries: [], allowance_entries: [], store_sales: [], tuition_bills: [],
    cert_requests: [], weekly_feedbacks: [], channels: [], channel_members: [], messages: [],
  });
  childList = [{ id:'s1', name:'홍길동', community_id:'c1', relation:'모' }]; childPicked = 's1';
  await renderChildPage();
  await new Promise(r => setTimeout(r, 300));
})()`;

(async () => {
const b = await launch();

console.log('\n① 아이가 하나여도 ＋ 아이 추가 가 보인다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(asParent);
  const r = await pg.evaluate(`(() => {
    const m = document.getElementById('child-main');
    return { btn: !!m.querySelector('button[onclick*="openAddChildModal"]'), n: childList.length };
  })()`);
  ok(r.n === 1 && r.btn, '아이가 하나일 때도 단추가 있다 — 둘째를 어디서 더하는지 알 수 있어야 한다');
  await pg.close(); }

console.log('\n② 확인 없이는 신청되지 않는다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(asParent);
  const r = await pg.evaluate(`(async () => {
    openAddChildModal();
    document.getElementById('ac-name').value = '홍길순';
    document.getElementById('ac-birth').value = '2014-05-06';
    await addChildRequest();                      // 확인 안 누르고 바로 신청
    await new Promise(r => setTimeout(r, 200));
    return { msg: document.getElementById('ac-msg').textContent,
             claim: ME.parent_claim_name, open: !!document.querySelector('.add-child-modal') };
  })()`);
  ok(/확인하기/.test(r.msg), '먼저 아이 확인하기를 누르라고 말한다');
  ok(!r.claim, '신청이 들어가지 않는다');
  ok(r.open, '창이 닫히지 않는다');
  await pg.close(); }

console.log('\n③ 이미 연결된 아이는 다시 못 더한다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(asParent);
  const r = await pg.evaluate(`(async () => {
    openAddChildModal();
    document.getElementById('ac-name').value = '홍길동';
    document.getElementById('ac-birth').value = '2011-03-04';
    await addChildFind();
    await new Promise(r => setTimeout(r, 200));
    return { msg: document.getElementById('ac-msg').textContent, okFlag: addChildOk };
  })()`);
  ok(/이미 연결된/.test(r.msg), '이미 연결된 아이라고 알려 준다');
  ok(r.okFlag === false, '그 상태로는 신청이 안 된다');
  await pg.close(); }

console.log('\n④ 확인하고 신청하면 — 바로 잇지 않고 신청만 남는다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(asParent);
  const r = await pg.evaluate(`(async () => {
    openAddChildModal();
    document.getElementById('ac-name').value = '홍길순';
    document.getElementById('ac-birth').value = '2014-05-06';
    document.getElementById('ac-rel').value = '모';
    addChildOk = true;                            // parent-verify 가 찾았다고 치고
    await addChildRequest();
    await new Promise(r => setTimeout(r, 400));
    const me = (window.__DB.members || []).find(x => x.id === 'p1');
    const mem = window.__DB.channel_members, msgs = window.__DB.messages;
    const got = {}; msgs.forEach(m => mem.filter(x => x.channel_id === m.channel_id && x.member_id !== 'p1')
                                         .forEach(x => got[x.member_id] = m.text));
    return { claim: me && me.parent_claim_name, birth: me && me.parent_claim_birth, rel: me && me.parent_claim_rel,
             links: (window.__DB.student_parents || []).length, got, body: document.body.innerText };
  })()`);
  ok(r.claim === '홍길순' && r.birth === '2014-05-06' && r.rel === '모', '신청 내용이 그대로 적힌다');
  ok(r.links === 0, '바로 이어지지 않는다 — 선생님 확인을 거친다');
  ok(/선생님이 확인하면 연결/.test(r.body), '언제 연결되는지 알려 준다');
  ok(!!r.got['t2'] && !!r.got['ao'], '담임과 행정담당자에게 알림이 간다');
  ok(/홍길순/.test(r.got['ao'] || '') && /연결 신청/.test(r.got['ao'] || ''), '알림에 누구를 신청했는지 들어 있다');
  await pg.close(); }

console.log('\n⑤ 관리자 화면 — 이미 이어진 학부모여도 새 신청이 보인다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(`(async () => {
    ME.community_role = 'super_admin';
    members['p1'] = { id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent', status:'approved',
                      parent_claim_name:'홍길순', parent_claim_birth:'2014-05-06', parent_claim_rel:'모' };
    members['s1'] = { id:'s1', name:'홍길동', community_id:'c1', community_role:'student', status:'approved' };
    members['s9'] = { id:'s9', name:'홍길순', community_id:'c1', community_role:'student', status:'approved' };
    window.__DB.members = Object.values(members).map(m => ({ ...m, community_id:'c1' }));
    window.__DB.student_parents = [{ parent_id:'p1', student_id:'s1', relation:'모' }];
    setMode('admin');
    await renderAdminMembers();
    await new Promise(r => setTimeout(r, 400));
    const a = document.getElementById('admin-content');
    const badge = [...a.querySelectorAll('div')]
      .filter(d => /👨‍👩‍👧/.test(d.textContent) && d.children.length <= 3)
      .map(d => d.innerText).join(' | ');
    return { txt: a.innerText, badge, link: !!a.querySelector('button[onclick*="admLinkClaimedChild"]') };
  })()`);
  ok(/홍길동/.test(r.badge), '학부모 쪽지에 이미 이어진 아이(홍길동)가 보인다');
  ok(/홍길순/.test(r.badge), '같은 쪽지에 새로 신청한 아이(홍길순)도 보인다 — 안 보이면 영영 안 이어진다');
  ok(/아직 연결 전/.test(r.badge), '아직 연결 전이라고 적혀 있다');
  ok(r.link, "'🔗 아이 연결' 단추가 있다");
  await pg.close(); }

console.log('\n⑥ 연결하면 신청 칸을 비운다');
{ const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(`(async () => {
    ME.community_role = 'super_admin';
    members['p1'] = { id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent', status:'approved',
                      parent_claim_name:'홍길순', parent_claim_birth:'2014-05-06', parent_claim_rel:'모' };
    window.__DB.members = Object.values(members).map(m => ({ ...m, community_id:'c1' }));
    window.__DB.student_parents = [];
    //  approve_parent RPC 는 서버 함수라 흉내만 낸다 — 이었다고 답하게
    const realRpc = sb.rpc;
    sb.rpc = () => ({ then: (res) => Promise.resolve({ data:{ ok:true, student_name:'홍길순' }, error:null }).then(res) });
    await admLinkClaimedChild('p1');
    sb.rpc = realRpc;
    await new Promise(r => setTimeout(r, 400));
    const me = (window.__DB.members || []).find(x => x.id === 'p1');
    return { claim: me && me.parent_claim_name, body: document.body.innerText };
  })()`);
  ok(r.claim === null, "이은 뒤에는 신청 칸이 비워진다 — 안 비우면 '아직 연결 전' 이 영영 남는다");
  await pg.close(); }

await b.close();
done();
})();
