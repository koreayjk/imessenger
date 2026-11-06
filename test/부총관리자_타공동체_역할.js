//  👤 부총관리자 — 다른 공동체에서는 **역할만** 바꾼다
//
//  요청: "부총관리자가 다른 공동체 멤버 교사에서 관리자로 올리는거 가능하게"
//  이건 앞서 세운 '다른 공동체는 눈으로만' 을 한 군데 여는 것이라,
//  **무엇이 열렸고 무엇이 그대로 막혀 있는지**를 글로 못 박아 둡니다.
const fs = require('fs'), path = require('path');
const { launch, openApp, ok, done, ROOT } = require('./_harness');

const SQL  = fs.readFileSync(path.join(ROOT, 'db', '부총관리자_타공동체_역할변경_DB설치.sql'), 'utf8')
               .replace(/--[^\n]*/g, '');
const GEN  = fs.readFileSync(path.join(ROOT, 'db', '부총관리자_권한_DB설치.sql'), 'utf8');

(async () => {
const b = await launch();

// ── ① 설치 SQL ───────────────────────────────────────────────
console.log('\n① 설치 SQL');
const chk = SQL.slice(SQL.indexOf('members_vice_other_comm_role_only'));
ok(/drop policy if exists members_vice_comm_upd on public\.members/.test(SQL),
   'members 의 고치기는 공동체 울타리에서 뺀다 (안 그러면 그게 먼저 걸린다)');
ok(/members_vice_other_comm_role_only/.test(SQL), '대신 역할만 열어 주는 정책을 세운다');

//  ⚠️ 한 번 틀린 자리 — '내 공동체인가' 를 바꾼 뒤 값으로 보면
//     남을 내 공동체로 끌어오는 것이 통과한다.
ok(/public\.member_community_of\(id\) = \(select public\.my_community_id\(\)\)/.test(chk),
   "'내 사람인가' 를 **바뀌기 전 소속**으로 본다 — 새 값으로 보면 남을 내 공동체로 끌어올 수 있다");

for (const col of ['name', 'status', 'photo_url', 'community_id']) {
  ok(new RegExp(col + '\\s+is not distinct from public\\.member_').test(chk),
     `남의 공동체에서는 ${col} 을 못 바꾼다`);
}
ok(!/community_role\s+is not distinct from/.test(chk),
   'community_role 만 빠져 있다 — 그게 열어 준 것이다');

ok(!/members_vice_comm_ins|members_vice_comm_del/.test(SQL.replace(/drop policy if exists members_vice_comm_upd[^;]*;/, '')),
   '넣기·지우기 울타리는 건드리지 않는다');

console.log('\n② 울타리 생성기');
ok(/if r\.tbl <> 'members' then/.test(GEN),
   '부총관리자_권한_DB설치.sql 을 다시 돌려도 members 고치기 울타리가 되살아나지 않는다');
ok(/_vice_comm_ins/.test(GEN) && /_vice_comm_del/.test(GEN),
   '다른 표와 넣기·지우기 울타리는 그대로 만든다');

// ── ③ 화면 ───────────────────────────────────────────────────
console.log('\n③ 다른 공동체를 보는 중인 화면');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.community_role = 'vice_admin';
    //  '다른 공동체를 보는 중' 으로 만든다
    const realIn = window.inHomeCommunity;
    window.inHomeCommunity = () => false;
    const guest = isGuestViewing();
    const 열리나 = canOpenAdmin();
    window.__DB.members = [
      { id:'me', name:'부총', community_id:'c1', community_role:'vice_admin', status:'approved' },
      { id:'t9', name:'남의교사', community_id:'c1', community_role:'teacher', status:'approved' },
      { id:'pz', name:'대기중', community_id:'c1', community_role:'teacher', status:'pending' },
    ];
    await renderAdminMembers();
    const row = [...document.querySelectorAll('#admin-content .adm-row')].find(x => x.textContent.includes('남의교사'));
    const main = document.getElementById('admin-content');
    const out = {
      guest, 열리나,
      역할칸: !!(row && row.querySelector('select[onchange^="changeMemberCommunityRole"]')),
      탈퇴: !!(row && row.querySelector('button[onclick^="deleteMember"]')),
      이름고치기: !!(row && row.querySelector('button[onclick^="renameMember"]')),
      승인대기: /승인 대기 중|Pending Approval/.test(main.textContent),
      멤버쓰기열림: GUEST_WRITABLE.has('members'),
      메시지쓰기열림: GUEST_WRITABLE.has('messages'),
      기도쓰기열림: GUEST_WRITABLE.has('prayers'),
    };
    window.inHomeCommunity = realIn;
    ME.community_role = 'community_admin';
    return out;
  });

  ok(r.guest, '손님(다른 공동체를 보는 중)으로 잡힌다');
  ok(r.열리나, '관리자 페이지를 열 수 있다 — 전에는 아예 못 들어갔다');
  ok(r.역할칸, '역할 칸이 보인다 ← 이게 요청이었다');
  ok(!r.탈퇴, '탈퇴 단추는 없다');
  ok(!r.이름고치기, '이름 고치기도 없다');
  ok(!r.승인대기, '승인 대기 묶음을 아예 안 보여 준다 — 눌러도 서버가 막는다');
  ok(r.멤버쓰기열림, 'members 저장이 손님 가드를 지나간다 (무엇을 바꿀 수 있나는 서버가 정한다)');
  ok(r.메시지쓰기열림, '채팅은 전처럼 열려 있다');
  ok(!r.기도쓰기열림, '기도제목 같은 다른 표는 그대로 막혀 있다');
  await pg.close();
}

// ── ④ 내 공동체에서는 전과 같나 ───────────────────────────────
console.log('\n④ 내 공동체에서는 전과 같다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.community_role = 'vice_admin';
    window.__DB.members = [
      { id:'me', name:'부총', community_id:'c1', community_role:'vice_admin', status:'approved' },
      { id:'t9', name:'우리교사', community_id:'c1', community_role:'teacher', status:'approved' },
      { id:'pz', name:'대기중', community_id:'c1', community_role:'teacher', status:'pending' },
    ];
    await renderAdminMembers();
    const row = [...document.querySelectorAll('#admin-content .adm-row')].find(x => x.textContent.includes('우리교사'));
    const main = document.getElementById('admin-content');
    const out = {
      guest: isGuestViewing(),
      역할칸: !!(row && row.querySelector('select[onchange^="changeMemberCommunityRole"]')),
      탈퇴: !!(row && row.querySelector('button[onclick^="deleteMember"]')),
      승인대기: /승인 대기 중|Pending Approval/.test(main.textContent),
    };
    ME.community_role = 'community_admin';
    return out;
  });
  ok(!r.guest, '내 공동체에서는 손님이 아니다');
  ok(r.역할칸 && r.탈퇴, '역할 바꾸기·탈퇴가 전처럼 다 있다');
  ok(r.승인대기, '승인 대기 묶음도 전처럼 보인다');
  await pg.close();
}

await b.close();
done();
})();
