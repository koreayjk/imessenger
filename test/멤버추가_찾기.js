//  ＋ 채팅방에 멤버 추가 — 찾기 · 공동체별로 접기 · 역할 차례
//
//    "너무 사람이 많아서 일일이 찾기 힘들잖아. 그래서 여기에 찾기 기능 넣어줘
//     그리고 공동체별로 그룹별로 지정해줘서 처음에는 공동체이름만 보이고
//     옆에 + 나 다 보기 이런거 누르면 그 공동체 멤버 다 보여지게해주고
//     공동체 멤버 보여지게 할때 위에는 관리자 선생님 간사 학생 이런순으로"
//
//  ⚠️ 접었다 펴면 그 줄이 화면에서 사라집니다. 고른 사람을 화면에서
//     읽으면 접자마자 날아갑니다 — 그래서 amPicked 에 담습니다.
const { launch, openApp, ok, done } = require('./_harness');

//  🌐 후보 — 일부러 역할을 뒤섞어 둔다
const CAND = [
  { id:'h1', name:'한학생',  community_id:'c1', community_role:'student',        community_name:'IM HQ' },
  { id:'h2', name:'가관리',  community_id:'c1', community_role:'community_admin', community_name:'IM HQ' },
  { id:'h3', name:'다간사',  community_id:'c1', community_role:'staff',          community_name:'IM HQ' },
  { id:'h4', name:'나교사',  community_id:'c1', community_role:'teacher',        community_name:'IM HQ' },
  { id:'h5', name:'마학부모', community_id:'c1', community_role:'parent',        community_name:'IM HQ' },
  { id:'h6', name:'하총관',  community_id:'c1', community_role:'super_admin',    community_name:'IM HQ' },
  { id:'u1', name:'미국학생', community_id:'c9', community_role:'student',       community_name:'IM USA' },
  { id:'u2', name:'미국교사', community_id:'c9', community_role:'teacher',       community_name:'IM USA' },
  { id:'b1', name:'봇',      community_id:'c1', community_role:'store_bot',      community_name:'IM HQ' },
  { id:'r1', name:'떠난사람', community_id:'c9', community_role:'student',       community_name:'IM USA', status:'removed' },
];
const GROUPS = [{ id:'g3', community_id:'c1', name:'연합모임', sort:10, cross_community:true }];

async function openIt(b) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(async (d) => {
    window.__DB.channel_groups = d.GROUPS;
    window.__DB['rpc:cross_invite_candidates'] = d.CAND;
    await loadChannelGroups();
    ME.community_role = 'super_admin'; ME.community_id = 'c1';
    members[ME.id] = ME;
    currentChannel = { id:'ch1', name:'연합방', kind:'topic', community_id:'c1', group_id:'g3' };
    currentChannelMemberIds = new Set();
    await openAddMemberModal();
  }, { GROUPS, CAND });
  return pg;
}
const read = `() => {
  const m = document.querySelector('.add-member-modal');
  return {
    comms: [...m.querySelectorAll('[data-am-comm]')].map(x => x.dataset.amComm),
    //  한 줄은 [머리글자, 이름, 역할] 로 읽힌다 — 이름은 두 번째다.
    //  처음에 첫 번째로 읽어서 '하 → 가 → 나' 가 나왔다 (머리글자였다).
    rows:  [...m.querySelectorAll('[data-am-row]')].map(x => x.innerText.split('\\n').map(s=>s.trim()).filter(Boolean)[1]),
    roles: [...m.querySelectorAll('[data-am-row]')].map(x => x.innerText.split('\\n').map(s=>s.trim()).filter(Boolean)[2]),
    roleTabs: [...m.querySelectorAll('[data-am-role]')].map(x => x.dataset.amRole),
    roleOn:   [...m.querySelectorAll('[data-am-role]')]
                .filter(x => x.style.color === 'rgb(255, 255, 255)').map(x => x.dataset.amRole),
    roleTxt:  (document.getElementById('am-roles')||{}).innerText || '',
    picked: [...amPicked],
    count: (document.getElementById('am-count')||{}).textContent || '',
    txt: m.innerText,
  };
}`;

(async () => {
const b = await launch();

// ── ① 처음에는 공동체 이름만 ──────────────────────────────────
console.log('\n① 처음에는 공동체 이름만');
{
  const pg = await openIt(b);
  const r = await pg.evaluate(eval(read));
  ok(r.comms.length === 2, '공동체 두 묶음이 나온다 (IM HQ · IM USA)');
  ok(r.comms[0] === 'IM HQ', '내 공동체가 맨 위에 온다');
  ok(r.rows.length === 0, '처음에는 사람이 한 명도 안 펼쳐진다 ← 이게 요청이었다');
  ok(/다 보기/.test(r.txt), '＋ 다 보기 가 보인다');
  ok(/6명/.test(r.txt), 'IM HQ 6명 — 봇은 빠졌다 (c1 에 7명인데 봇 하나 빠짐)');
  ok(/2명/.test(r.txt), 'IM USA 2명 — 떠난 사람은 빠졌다 (c9 에 3명인데 하나 빠짐)');
  await pg.close();
}

// ── ② 다 보기를 누르면 펼쳐지고, 역할 차례로 나온다 ───────────
console.log('\n② 다 보기 · 역할 차례');
{
  const pg = await openIt(b);
  const r = await pg.evaluate((rd) => {
    amToggleComm('IM HQ');
    return eval(rd)();
  }, read);
  ok(r.rows.length === 6, 'IM HQ 를 펼치면 6명이 나온다');
  ok(r.comms.length === 2, 'IM USA 는 접힌 채로 남아 있다');
  console.log('       차례:', r.rows.join(' → '));
  ok(r.rows.join(',') === '하총관,가관리,나교사,다간사,한학생,마학부모',
     '총관리자 → 관리자 → 교사 → 간사 → 학생 → 학부모 차례 ← 이게 요청이었다');
  ok(r.roles[0] === '총관리자' && r.roles[2] === '교사' && r.roles[3] === '간사',
     '역할이 이름 밑에 적힌다');
  ok(r.rows.indexOf('마학부모') > r.rows.indexOf('한학생'), '학부모는 학생보다 뒤다');
  await pg.close();
}

// ── ③ 찾기 ────────────────────────────────────────────────────
console.log('\n③ 이름으로 찾기');
{
  const pg = await openIt(b);
  const r = await pg.evaluate(async (rd) => {
    const out = {};
    amDoSearch('미국');
    out.name = eval(rd)();
    amDoSearch('교사');
    out.role = eval(rd)();
    amDoSearch('IM USA');
    out.comm = eval(rd)();
    amDoSearch('없는사람');
    out.none = eval(rd)();
    amDoSearch('');
    out.back = eval(rd)();
    return out;
  }, read);

  ok(r.name.rows.join(',') === '미국교사,미국학생',
     "'미국' 으로 찾으면 두 명이 나온다");
  ok(r.name.comms.length === 1, '걸리는 공동체만 나온다');
  ok(r.name.rows.length > 0, '찾는 중에는 접어 두지 않는다 ← 찾으라고 쓰는 칸이다');
  ok(r.role.rows.join(',') === '나교사,미국교사', "역할('교사')로도 찾아진다");
  ok(r.comm.rows.join(',') === '미국교사,미국학생', '공동체 이름으로도 찾아진다');
  ok(/찾는 사람이 없어요/.test(r.none.txt), '없으면 없다고 알려준다');
  ok(r.back.rows.length === 0 && r.back.comms.length === 2,
     '찾기를 비우면 다시 접힌 상태로 돌아온다');
  await pg.close();
}

// ── ④ 접었다 펴도 고른 사람이 안 날아간다 ─────────────────────
console.log('\n④ 접었다 펴도 안 날아간다');
{
  const pg = await openIt(b);
  const r = await pg.evaluate(async (rd) => {
    const out = {};
    amToggleComm('IM HQ');
    amTogglePick('h4');            // 나교사
    out.after = eval(rd)();
    amToggleComm('IM HQ');         // 접는다 — 그 줄이 화면에서 사라진다
    out.closed = eval(rd)();
    amToggleComm('IM HQ');         // 다시 편다
    out.reopened = eval(rd)();
    //  실제로 보내는 값
    window.__ins = [];
    await confirmAddMembers();
    out.sent = JSON.stringify(window.__ins);
    return out;
  }, read);

  ok(r.after.picked.join(',') === 'h4', '한 명 골랐다');
  ok(/1명 고름/.test(r.after.count), '몇 명 골랐는지 밑에 보여준다');
  ok(r.closed.rows.length === 0, '접으면 줄이 화면에서 사라진다');
  ok(r.closed.picked.join(',') === 'h4',
     '접어도 고른 사람이 남아 있다 ← 화면에서 읽으면 날아간다');
  ok(r.reopened.picked.join(',') === 'h4', '다시 펴도 그대로다');
  ok(/"member_id":"h4"/.test(r.sent), '접힌 채로 추가해도 그 사람이 들어간다');
  await pg.close();
}

// ── ⑤ 공동체 통째로 고르기 ────────────────────────────────────
console.log('\n⑤ 공동체 통째로 고르기');
{
  const pg = await openIt(b);
  const r = await pg.evaluate(async (rd) => {
    const out = {};
    amToggleComm('IM USA');
    amPickComm('IM USA', true);
    out.on = eval(rd)();
    amPickComm('IM USA', false);
    out.off = eval(rd)();
    return out;
  }, read);
  ok(r.on.picked.sort().join(',') === 'u1,u2', 'IM USA 를 통째로 고르면 그 공동체 2명이 들어간다');
  ok(!r.on.picked.includes('h1'), '다른 공동체 사람은 안 들어간다');
  ok(/모두 풀기/.test(r.on.txt), '다 골랐으면 모두 풀기 로 바뀐다');
  ok(r.off.picked.length === 0, '모두 풀기가 된다');
  await pg.close();
}

// ── ⑥ 우리 공동체 방은 전과 같다 ──────────────────────────────
console.log('\n⑥ 보통 방');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rd) => {
    window.__DB.channel_groups = [];
    await loadChannelGroups();
    ME.community_role = 'community_admin'; ME.community_id = 'c1';
    members['x1'] = { id:'x1', name:'우리학생', community_id:'c1', community_role:'student' };
    members['x2'] = { id:'x2', name:'우리교사', community_id:'c1', community_role:'teacher' };
    members[ME.id] = ME;
    currentChannel = { id:'ch2', name:'우리방', kind:'topic', community_id:'c1', group_id:null };
    currentChannelMemberIds = new Set();
    await openAddMemberModal();
    return eval(rd)();
  }, read);
  ok(r.comms.length === 1, '묶음이 하나다');
  ok(r.rows.length >= 2, '처음부터 펼쳐져 있다 ← 묶을 것이 하나뿐이면 접을 이유가 없다');
  console.log('       보통 방 차례:', JSON.stringify(r.rows));
  ok(r.rows.indexOf('우리교사') < r.rows.indexOf('우리학생'), '여기도 교사가 학생보다 위다');
  ok(!/모든 공동체/.test(r.txt), '🌐 안내는 안 뜬다');
  await pg.close();
}

// ── ⑦ 직책으로 거르기 ────────────────────────────────────────
console.log('\n⑦ 직책으로 거르기');
{
  const pg = await openIt(b);
  const r = await pg.evaluate(async (rd) => {
    const out = {};
    out.first = eval(rd)();
    amPickRole('student');  out.student = eval(rd)();
    amPickRole('admin');    out.admin   = eval(rd)();
    amPickRole('staff');    out.staff   = eval(rd)();
    amPickRole('staff');    out.again   = eval(rd)();   // 같은 걸 또 누르면 전체
    //  찾기와 같이 걸리나
    amPickRole('teacher'); amDoSearch('미국');
    out.both = eval(rd)();
    amDoSearch(''); amPickRole('teacher');
    return out;
  }, read);

  ok(r.first.roleTabs.join(',') === ',admin,teacher,staff,student,parent',
     '전체 + 관리자·교사·간사·학생·학부모 거르개가 나온다 ← 이게 요청이었다');
  ok(/관리자/.test(r.first.roleTxt) && /간사/.test(r.first.roleTxt) && /학생/.test(r.first.roleTxt),
     '관리자 · 간사 · 학생 이라고 적혀 있다');
  ok(r.first.roleOn.length === 1 && r.first.roleOn[0] === '', '처음에는 전체에 불이 들어와 있다');

  ok(r.student.rows.join(',') === '한학생,미국학생', '학생만 걸러진다');
  ok(r.student.roleOn.join(',') === 'student', '누른 거르개에 불이 들어온다');
  ok(r.student.rows.length > 0, '거르면 접어 두지 않는다 ← 접으면 아무것도 안 보인다');

  ok(r.admin.rows.join(',') === '하총관,가관리',
     '총관리자·관리자가 관리자 한 갈래로 묶인다');
  ok(r.staff.rows.join(',') === '다간사', '간사만 걸러진다');
  //  전체로 돌아오면 다시 접힌다 (거르개가 없으면 접힌 상태가 기본)
  //  '전체' 단추(값이 빈 글자)에 불이 들어온 상태가 전체다
  ok(r.again.roleOn.join(',') === '' && r.again.comms.length === 2 && r.again.rows.length === 0,
     '같은 거르개를 또 누르면 전체로 돌아오고 다시 접힌다');

  ok(r.both.rows.join(',') === '미국교사',
     "직책(교사)과 찾기('미국')가 함께 걸린다");
  await pg.close();
}

// ── ⑧ 거를 것이 없으면 거르개를 안 보여준다 ───────────────────
console.log('\n⑧ 거를 것이 없으면');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rd) => {
    window.__DB.channel_groups = [];
    await loadChannelGroups();
    ME.community_role = 'community_admin'; ME.community_id = 'c1';
    for (const k of Object.keys(members)) if (k !== ME.id) delete members[k];
    members['s1'] = { id:'s1', name:'학생하나', community_id:'c1', community_role:'student' };
    members['s2'] = { id:'s2', name:'학생둘',  community_id:'c1', community_role:'student' };
    members[ME.id] = ME;
    currentChannel = { id:'ch3', name:'우리방', kind:'topic', community_id:'c1', group_id:null };
    currentChannelMemberIds = new Set();
    await openAddMemberModal();
    const box = document.getElementById('am-roles');
    return { hidden: box.style.display === 'none', tabs: box.innerHTML.length };
  }, read);
  ok(r.hidden && r.tabs === 0,
     '전부 학생뿐이면 거르개를 안 보여준다 ← 거를 것이 없는데 자리만 차지한다');
  await pg.close();
}

await b.close();
done();
})();
