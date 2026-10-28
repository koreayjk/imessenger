// 📄 서류 신청 → 담임 + 행정담당자에게 알림
const { launch, openApp, ok, done } = require('./_harness');

//  학부모가 '내 아이' 화면에서 재학증명서를 신청하는 상황
const setup = (extra) => `(async () => {
  members['t2'] = { id:'t2', name:'박교사', community_id:'c1', community_role:'teacher', status:'approved' };
  members['ao'] = { id:'ao', name:'행정샘', community_id:'c1', community_role:'admin_officer', status:'approved' };
  members['ad'] = { id:'ad', name:'최관리', community_id:'c1', community_role:'community_admin', status:'approved' };
  Object.assign(window.__DB, {
    members: Object.values(members).map(m => ({ ...m, community_id:'c1' })),
    student_homerooms: [{ community_id:'c1', student_id:'s1', teacher_id:'t2' }],
    deposit_entries: [], allowance_entries: [], store_sales: [], tuition_bills: [],
    cert_requests: [], weekly_feedbacks: [], channels: [], channel_members: [], messages: [],
    ${extra || ''}
  });
  childList = [{ id:'s1', name:'홍길동', community_id:'c1', relation:'모' }]; childPicked = 's1';
  await renderChildPage();
  await new Promise(r => setTimeout(r, 300));
  document.getElementById('child-cert-purpose').value = '학교 제출용';
  document.getElementById('child-cert-copies').value = '2';
  await childCertRequest();
  await new Promise(r => setTimeout(r, 400));
})()`;

const read = `(() => {
  const msgs = (window.__DB.messages || []);
  const chs  = (window.__DB.channels || []);
  const mem  = (window.__DB.channel_members || []);
  const got  = {};
  msgs.forEach(m => {
    const others = mem.filter(x => x.channel_id === m.channel_id && x.member_id !== 'p1').map(x => x.member_id);
    others.forEach(o => { got[o] = m.text; });
  });
  return { got, nMsg: msgs.length, nCh: chs.length,
           req: (window.__DB.cert_requests || []).length,
           toast: document.body.innerText };
})()`;

(async () => {
const b = await launch();

console.log('\n① 담임과 행정담당자 둘 다에게 간다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(setup());
  const r = await pg.evaluate(read);
  ok(r.req === 1, '신청이 먼저 들어간다');
  ok(!!r.got['t2'], '담임(박교사)에게 간다');
  ok(!!r.got['ao'], '행정담당자(행정샘)에게 간다');
  ok(!r.got['ad'], '행정담당자가 있으면 관리자에게는 안 간다 — 아무에게나 뿌리지 않는다');
  ok(r.nMsg === 2, '두 사람에게 한 통씩, 딱 두 통');
  await pg.close(); }

console.log('\n② 글에 들어 있어야 할 것');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(setup());
  const r = await pg.evaluate(read);
  const txt = r.got['ao'] || '';
  ok(/홍길동/.test(txt), '누구 서류인지 (홍길동)');
  ok(/재학증명서/.test(txt), '무슨 서류인지 (재학증명서)');
  ok(/2부/.test(txt), '몇 부인지 (2부)');
  ok(/학교 제출용/.test(txt), '어디에 내는지 (학교 제출용)');
  ok(/홍어머니/.test(txt), '누가 신청했는지 (홍어머니)');
  ok(/증명서/.test(txt) && /발급/.test(txt), '어디서 발급하면 되는지 알려준다');
  await pg.close(); }

console.log('\n③ 행정담당자가 없으면 관리자에게');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(`(async () => { delete members['ao']; })()`);
  await pg.evaluate(setup());
  await pg.evaluate(`(async () => { window.__DB.members = window.__DB.members.filter(m => m.id !== 'ao'); })()`);
  const r2 = await pg.evaluate(`(async () => {
    window.__DB.messages = []; window.__DB.channels = []; window.__DB.channel_members = [];
    document.getElementById('child-cert-purpose').value = '은행 제출용';
    await childCertRequest();
    await new Promise(r => setTimeout(r, 400));
    const mem = window.__DB.channel_members, msgs = window.__DB.messages;
    const got = {};
    msgs.forEach(m => mem.filter(x => x.channel_id === m.channel_id && x.member_id !== 'p1')
                         .forEach(x => got[x.member_id] = m.text));
    return got;
  })()`);
  ok(!!r2['ad'], '행정담당자가 없으면 관리자(최관리)에게 간다 — 알림이 사라지지 않는다');
  ok(!!r2['t2'], '담임에게는 그대로 간다');
  await pg.close(); }

console.log('\n④ 담당표가 비어 있으면 예전 칸을 본다');
{ const pg = await openApp(b, { as:'parent' });
  await pg.evaluate(setup("student_homerooms: [],"));
  const r = await pg.evaluate(`(() => {
    const mem = window.__DB.channel_members, msgs = window.__DB.messages;
    const got = {}; msgs.forEach(m => mem.filter(x => x.channel_id === m.channel_id && x.member_id !== 'p1')
                                         .forEach(x => got[x.member_id] = m.text));
    return got;
  })()`);
  ok(!r['t2'], '담당표가 비면 담임은 못 찾는다 (members.homeroom_teacher_id 도 비어 있으니)');
  ok(!!r['ao'], '그래도 행정담당자에게는 간다 — 한쪽이 비어도 신청이 묻히지 않는다');
  const r2 = await pg.evaluate(`(async () => {
    //  예전 칸(members.homeroom_teacher_id)이 적혀 있으면 그걸로 찾아야 한다
    window.__DB.members = window.__DB.members.map(m => m.id === 's1' ? { ...m, homeroom_teacher_id:'t2' } : m);
    window.__DB.messages = []; window.__DB.channels = []; window.__DB.channel_members = [];
    document.getElementById('child-cert-purpose').value = '학교 제출용';
    await childCertRequest();
    await new Promise(r => setTimeout(r, 400));
    const mem = window.__DB.channel_members, msgs = window.__DB.messages;
    const got = {}; msgs.forEach(m => mem.filter(x => x.channel_id === m.channel_id && x.member_id !== 'p1')
                                         .forEach(x => got[x.member_id] = m.text));
    return got;
  })()`);
  ok(!!r2['t2'], '예전 칸에 담임이 적혀 있으면 그걸로 찾는다');
  await pg.close(); }

console.log('\n⑤ 알리지 못했으면 알렸다고 하지 않는다');
{ const pg = await openApp(b, { as:'parent' });
  const r = await pg.evaluate(`(async () => {
    //  선생님도 행정담당자도 담임도 없는 공동체 — 보낼 사람이 하나도 없다
    ['t2','ao','ad'].forEach(k => delete members[k]);
    Object.assign(window.__DB, {
      members: [{ id:'p1', name:'홍어머니', community_id:'c1', community_role:'parent' },
                { id:'s1', name:'홍길동',   community_id:'c1', community_role:'student' }],
      student_homerooms: [], channels: [], channel_members: [], messages: [],
      deposit_entries: [], allowance_entries: [], store_sales: [], tuition_bills: [],
      cert_requests: [], weekly_feedbacks: [],
    });
    childList = [{ id:'s1', name:'홍길동', community_id:'c1', relation:'모' }]; childPicked = 's1';
    await renderChildPage();
    await new Promise(r => setTimeout(r, 300));
    document.getElementById('child-cert-purpose').value = '학교 제출용';
    await childCertRequest();
    await new Promise(r => setTimeout(r, 400));
    return { n: window.__DB.messages.length, body: document.body.innerText,
             req: window.__DB.cert_requests.length };
  })()`);
  ok(r.n === 0, '보낼 사람이 없으면 아무 데도 안 보낸다');
  ok(!/알림이 갔어요/.test(r.body), "'알림이 갔어요' 라고 말하지 않는다");
  ok(r.req >= 1, '그래도 신청 자체는 남는다 — 알림이 막혀도 신청은 살아야 한다');
  await pg.close(); }

await b.close();
done();
})();
