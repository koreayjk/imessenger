//  🔄 탈퇴한 멤버 되살리기
//
//  개선창 · grace (아임홈스쿨러 미니스트리, 11/14):
//    「탈퇴된 메일 다시 가입이 안되나요?? … 탈퇴 요청 하셔서 탈퇴해드렸었는데
//      다시 가입하려고 하니 안된다고 하시네요」
//
//  까닭: 탈퇴는 표에서 지우는 게 아닙니다. members.status 를 'removed' 로
//        바꾸는 것뿐입니다 (하드 삭제는 규칙(RLS)으로 막혀 있습니다).
//        로그인 계정이 그대로 남아 있으니 **그 메일로는 다시 가입이 안 됩니다.**
//        그리고 'removed' 는 관리 ▸ 멤버 어디에도 안 그려져서,
//        **되살릴 길이 화면에 아예 없었습니다.**
//
//  그래서 「거절된 멤버」 칸과 같은 모양으로 「탈퇴한 멤버」 칸을 두고
//  되살리기 단추를 답니다. 다시 가입이 아니라 되살리는 것이 맞는 답입니다.
//
//  재는 것:
//   ① 탈퇴한 멤버가 따로 보이나 (평소 목록에는 안 섞이나)
//   ② 되살리면 status 가 approved 로 가나
//   ③ 규칙에 막혀 0건이면 되살렸다고 거짓말하지 않나
//   ④ 손님(둘러보기)에게는 단추가 안 보이나
//   ⑤ 탈퇴한 사람이 없으면 칸 자체가 없나
const { launch, openApp, ok, done } = require('./_harness');

const BASE = [
  { id:'me', name:'김선생', email:'t@example.com',   community_id:'c1', community_role:'community_admin', status:'approved' },
  { id:'s1', name:'홍길동', email:'g@example.com',   community_id:'c1', community_role:'student',         status:'approved' },
  { id:'x1', name:'박나감', email:'gone@example.com',community_id:'c1', community_role:'parent',          status:'removed'  },
  { id:'r1', name:'최거절', email:'no@example.com',  community_id:'c1', community_role:'student',         status:'rejected' },
];

async function openAdmin(b, members) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(async (ms) => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1';
    ME.community_role = 'community_admin'; ME.email = 't@example.com';
    window.__DB.communities = [{ id:'c1', name:'행복한 공동체', kind:'community',
                                 created_at:'2026-01-01T00:00:00Z', color:'#1d3a5f' }];
    window.__DB.members = JSON.parse(JSON.stringify(ms));
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
    window.confirm = () => true;
    enterApp(); setMode('admin');
    await new Promise(r => setTimeout(r, 300));
    switchAdminTab('members');
  }, members);
  await pg.waitForTimeout(900);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 탈퇴한 멤버가 따로 보인다 ─────────────────────────────
console.log('\n① 탈퇴한 멤버 칸');
{
  const pg = await openAdmin(b, BASE);
  const r = await pg.evaluate(() => {
    const box = document.getElementById('admin-content');
    const btn = box.querySelector('button[onclick*="restoreMember"]');
    //  평소 멤버 목록(승인된 사람 칸)에 섞여 있지 않은지
    const cards = [...box.querySelectorAll('.adm-card')];
    const normal = cards.find(c => /멤버 \d+명/.test(c.innerText || ''));
    return {
      hasSection: /탈퇴한 멤버/.test(box.innerText),
      count:      (box.innerText.match(/탈퇴한 멤버 (\d+)명/) || [])[1],
      btn:        !!btn,
      btnFor:     btn ? btn.getAttribute('onclick') : '',
      inNormal:   normal ? /박나감/.test(normal.innerText) : null,
      saysWhy:    /다시 가입이 안 됩니다/.test(box.innerText),
      rejectedToo:/거절된 멤버/.test(box.innerText),
    };
  });
  ok(r.hasSection,            '「탈퇴한 멤버」 칸이 있다');
  ok(r.count === '1',         '탈퇴한 사람 수를 센다', r.count);
  ok(r.btn,                   '되살리기 단추가 있다');
  ok(/x1/.test(r.btnFor),     '그 사람을 가리킨다', r.btnFor);
  ok(r.inNormal === false,    '평소 멤버 목록에는 안 섞인다', String(r.inNormal));
  ok(r.saysWhy,               '왜 다시 가입이 안 되는지 적어 둔다');
  ok(r.rejectedToo,           '거절된 멤버 칸은 그대로 있다');
  await pg.close();
}

// ── ② 되살리면 approved 로 ──────────────────────────────────
console.log('\n② 되살리기');
{
  const pg = await openAdmin(b, BASE);
  const r = await pg.evaluate(async () => {
    await restoreMember('x1', '박나감');
    await new Promise(r => setTimeout(r, 600));
    const upd = (window.__upd || []).filter(x => x.t === 'members');
    const box = document.getElementById('admin-content');
    return {
      upd:   upd.map(x => JSON.stringify(x.patch || x.vals || x)),
      row:   (window.__DB.members || []).find(x => x.id === 'x1'),
      other: (window.__DB.members || []).find(x => x.id === 'r1'),
      toast: window.__toast.join('|'),
      gone:  !/탈퇴한 멤버/.test(box.innerText),
      back:  /박나감/.test(box.innerText),
    };
  });
  ok(/approved/.test(r.upd.join('|')), "status 를 approved 로 보낸다", r.upd.join('|'));
  ok(r.row && r.row.status === 'approved', '표에서도 approved 다', r.row && r.row.status);
  ok(r.other && r.other.status === 'rejected', '거절된 사람은 안 건드린다', r.other && r.other.status);
  ok(/되살렸어요/.test(r.toast), '되살렸다고 알려 준다', r.toast);
  ok(r.gone, '탈퇴한 멤버 칸이 사라진다 (아무도 안 남았으니)', String(r.gone));
  ok(r.back, '평소 목록에 돌아온다', String(r.back));
  await pg.close();
}

// ── ③ 규칙에 막혀 0건이면 ──────────────────────────────────
console.log('\n③ 0건으로 돌아왔을 때');
{
  const pg = await openAdmin(b, BASE);
  const r = await pg.evaluate(async () => {
    const real = sb.from;
    sb.from = (tb) => tb === 'members'
      ? { update: () => ({ eq: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }) }
      : real(tb);
    window.__toast = [];
    await restoreMember('x1', '박나감');
    sb.from = real;
    return { status: (window.__DB.members || []).find(x => x.id === 'x1').status,
             toast: window.__toast.join('|') };
  });
  ok(r.status === 'removed', '막혔으면 그대로 탈퇴 상태다', r.status);
  ok(!/되살렸어요/.test(r.toast), '되살렸다고 하지 않는다', r.toast);
  ok(/권한이 없어요|권한/.test(r.toast), '권한이 없다고 말해 준다', r.toast);
  await pg.close();
}

// ── ④ 둘러보기(손님)에게는 안 보인다 ────────────────────────
console.log('\n④ 손님으로 볼 때');
{
  const pg = await openAdmin(b, BASE);
  const r = await pg.evaluate(async () => {
    if (typeof isGuestViewing !== 'function') return { skip:true };
    window.isGuestViewing = () => true;
    await renderAdminMembers();
    await new Promise(r => setTimeout(r, 500));
    const box = document.getElementById('admin-content');
    return { section: /탈퇴한 멤버/.test(box.innerText),
             btn: !!box.querySelector('button[onclick*="restoreMember"]') };
  });
  if (r.skip) { ok(true, '(isGuestViewing 이 없어 건너뜀)'); }
  else {
    ok(!r.section, '손님에게는 탈퇴한 멤버 칸이 안 보인다', String(r.section));
    ok(!r.btn,     '손님에게는 되살리기 단추도 없다', String(r.btn));
  }
  await pg.close();
}

// ── ⑤ 탈퇴한 사람이 없으면 ─────────────────────────────────
console.log('\n⑤ 탈퇴한 사람이 없을 때');
{
  const pg = await openAdmin(b, BASE.filter(m => m.status !== 'removed'));
  const r = await pg.evaluate(() => {
    const box = document.getElementById('admin-content');
    return { section: /탈퇴한 멤버/.test(box.innerText),
             members: /멤버 \d+명/.test(box.innerText) };
  });
  ok(!r.section, '칸을 아예 띄우지 않는다', String(r.section));
  ok(r.members,  '평소 목록은 그대로 나온다');
  await pg.close();
}

await b.close();
done();
})();
