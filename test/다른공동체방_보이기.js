//  🌐 남의 공동체에 있는 내 방이 보여야 한다 — 실제로 겪은 일
//
//    "전체 리뉴젠 공동체 소통창 그룹에서 전체 리뉴젠 사역자 소통창에
//     유은혜를 추가했는데 유은혜님이 로그인했는데 창이 안보인데"
//
//  재 보니 서버는 멀쩡했습니다. 유은혜(IM HQ)는 방 멤버로 제대로
//  들어가 있었고, 규칙(RLS)도 읽기를 허락합니다.
//  앱이 방 목록을 `community_id = 내 공동체` 로만 불러와서, IM USA 에
//  있는 그 방을 **애초에 안 물어봤습니다.** 그래서 그룹만 보이고 안은 0개.
//
//  실제 자리 그대로 재현합니다: 그룹도 방도 IM USA · 보는 사람은 IM HQ.
const { launch, openApp, ok, done } = require('./_harness');

//  채널 목록을 '내 공동체 것만' 돌려주는 가짜 서버 — 진짜와 같게
const SEED = `() => {
  window.__DB.channels = [
    { id:'c_mine',  name:'우리방',                  kind:'topic', community_id:'c1', group_id:null,  created_at:'2026-01-01' },
    { id:'c_cross', name:'전체 리뉴젠 사역자 소통창', kind:'topic', community_id:'c9', group_id:'g_usa', created_at:'2026-01-02' },
    { id:'c_other', name:'남의 공동체 보통방',        kind:'topic', community_id:'c9', group_id:null,  created_at:'2026-01-03' },
  ];
  window.__DB.channel_groups = [
    { id:'g_usa', community_id:'c9', name:'전체 리뉴젠 공동체 소통창', sort:10, cross_community:true },
  ];
  //  나는 🌐 방에만 초대받았다 (남의 공동체 보통방에는 아니다)
  window.__DB.channel_members = [{ id:'cm1', channel_id:'c_cross', member_id:'eh' }];
}`;

async function run(pg, role) {
  return pg.evaluate(async ([seed, rl]) => {
    eval(seed)();
    ME = { id:'eh', name:'유은혜', community_id:'c1', community_role: rl, initials:'유', color:'#1d3a5f' };
    members[ME.id] = ME;
    channels = []; commGroups = []; myGroups = []; myChPref = {};
    await loadChannelGroups();

    //  init() 이 하는 그대로 — 내 공동체 방만 불러온 뒤 내 멤버십을 본다
    const { data: chRes } = await sb.from('channels').select('*').eq('community_id', CID());
    channels = sortChannels(chRes || []);
    const { data: myCh } = await sb.from('channel_members').select('channel_id,favorite').eq('member_id', ME.id);
    const myIds = new Set((myCh || []).map(r => r.channel_id));
    const before = channels.map(c => c.name);

    //  고친 자리 — **앱의 진짜 함수**를 부른다.
    //  여기서 로직을 베껴 쓰면 앱을 되돌려도 시험이 통과해 버린다.
    const added = await addMyOutsideChannels(myIds);
    return {
      added,
      before,
      after: channels.map(c => c.name),
      inGroup: channels.filter(c => c.group_id === 'g_usa').map(c => c.name),
      groups: commGroups.map(g => g.name),
    };
  }, [SEED, role]);
}

(async () => {
const b = await launch();

// ── ① 유은혜(IM HQ)가 IM USA 의 🌐 방을 본다 ─────────────────
console.log('\n① IM HQ 사람이 IM USA 의 🌐 방을 본다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await run(pg, 'community_admin');

  ok(r.groups.includes('전체 리뉴젠 공동체 소통창'),
     '🌐 그룹은 남의 공동체에 있어도 보인다 (이건 되고 있었다)');
  ok(!r.before.includes('전체 리뉴젠 사역자 소통창'),
     '내 공동체 것만 물으면 그 방이 안 온다 ← 이게 겪으신 일이다');
  ok(r.added === 1, '모자란 방 하나를 더 가져온다');
  ok(r.after.includes('전체 리뉴젠 사역자 소통창'),
     '내가 들어간 방은 남의 공동체에 있어도 가져온다 ← 고친 자리');
  ok(r.inGroup.join(',') === '전체 리뉴젠 사역자 소통창',
     '그 방이 🌐 그룹 안에 들어간다 (그룹이 0개가 아니게 된다)');
  ok(r.after.includes('우리방'), '우리 공동체 방은 그대로 있다');
  ok(!r.after.includes('남의 공동체 보통방'),
     '초대 안 받은 남의 공동체 방은 안 온다 ← 기본은 소속공동체만');
  await pg.close();
}

// ── ② 평소에는 더 묻지 않는다 ────────────────────────────────
console.log('\n② 평소에는 더 묻지 않는다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    window.__DB.channels = [
      { id:'c_mine', name:'우리방', kind:'topic', community_id:'c1', group_id:null, created_at:'2026-01-01' },
    ];
    window.__DB.channel_members = [{ id:'cm1', channel_id:'c_mine', member_id:'eh' }];
    ME = { id:'eh', name:'유은혜', community_id:'c1', community_role:'community_admin', initials:'유', color:'#1d3a5f' };
    const { data: chRes } = await sb.from('channels').select('*').eq('community_id', CID());
    channels = sortChannels(chRes || []);
    //  서버에 몇 번 묻는지 센다
    const before = (window.__DB.__hits || 0);
    let asked = 0;
    const realFrom = sb.from;
    sb.from = function (tbl) { if (tbl === 'channels') asked++; return realFrom.call(sb, tbl); };
    const added = await addMyOutsideChannels(new Set(['c_mine']));
    sb.from = realFrom;
    return { asked, added, names: channels.map(c => c.name) };
  });
  ok(r.asked === 0,
     '내 방이 전부 내 공동체에 있으면 서버에 한 번도 더 안 묻는다');
  ok(r.added === 0 && r.names.join(',') === '우리방', '목록도 그대로다');
  await pg.close();
}

// ── ③ 총·부총관리자도 마찬가지 ───────────────────────────────
console.log('\n③ 부총관리자');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await run(pg, 'vice_admin');
  ok(r.after.includes('전체 리뉴젠 사역자 소통창'), '부총관리자도 그 방이 보인다');
  await pg.close();
}

await b.close();
done();
})();
