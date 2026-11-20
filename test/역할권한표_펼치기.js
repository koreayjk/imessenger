//  🔑 역할별 권한 안내 — 눌러도 안 열리던 것
//
//  2강 강의 자료를 만들려고 관리 ▸ 멤버 화면을 찍다가 걸렸습니다.
//  「🔑 역할별 권한 안내 ▼ 펼치기」 를 눌러도 **아무 일도 일어나지 않았습니다.**
//
//  까닭: toggleRolesGuide() 가 renderMembers() 를 불렀습니다.
//        그건 **채팅 쪽 멤버 목록**을 그리는 함수이고, 맨 앞에서
//          const memberList = document.getElementById('member-list');
//          if (!memberList) return;
//        로 돌아가 버립니다. 관리자 화면에는 #member-list 가 없으니
//        rolesGuideOpen 만 뒤집히고 화면은 그대로였습니다.
//        이 안내를 그리는 것은 renderAdminMembers() 입니다.
//
//  ★ 여기서 재는 것
//   ① 처음엔 접혀 있다 (표가 없고 '▼ 펼치기')
//   ② 한 번 누르면 **표가 나온다** ('▲ 접기')
//   ③ 표에 역할 칸과 기능 줄이 다 들어 있다
//   ④ 다시 누르면 접힌다
//   ⑤ 관리자 화면에는 #member-list 가 없다 — 그래서 renderMembers() 로는 안 됐다
const { launch, openApp, ok, done } = require('./_harness');

async function openAdmin(b) {
  const pg = await openApp(b, { as:'teacher' });
  await pg.evaluate(async () => {
    ME.id = 'me'; ME.name = '김선생'; ME.community_id = 'c1';
    ME.community_role = 'community_admin'; ME.email = 'nobody@example.com';
    window.__DB.communities = [{ id:'c1', name:'행복한 공동체', kind:'community',
                                 created_at:'2026-01-01T00:00:00Z', color:'#1d3a5f' }];
    window.__DB.members = [
      { id:'me', name:'김선생', email:'t@example.com', community_id:'c1', community_role:'community_admin', status:'approved' },
      { id:'s1', name:'홍길동', email:'g@example.com', community_id:'c1', community_role:'student',         status:'approved' },
    ];
    enterApp(); setMode('admin');
    await new Promise(r => setTimeout(r, 300));
    switchAdminTab('members');
  });
  await pg.waitForTimeout(900);
  return pg;
}

const READ = (pg) => pg.evaluate(() => {
  const box = document.getElementById('admin-content');
  const tbl = [...box.querySelectorAll('table')].find(x => /기능/.test(x.innerText || ''));
  return {
    open:  /▲ 접기/.test(box.innerText),
    shut:  /▼ 펼치기/.test(box.innerText),
    rows:  tbl ? tbl.querySelectorAll('tbody tr').length : 0,
    cols:  tbl ? [...tbl.querySelectorAll('thead th')].map(x => x.innerText.trim()) : [],
    first: tbl ? (tbl.querySelector('tbody tr td') || {}).innerText : '',
    hasChatList: !!document.getElementById('member-list'),
  };
});

(async () => {
  const b = await launch();

  console.log('\n① 처음엔 접혀 있다');
  const pg = await openAdmin(b);
  let r = await READ(pg);
  ok(r.shut === true,  "'▼ 펼치기' 라고 적혀 있다", JSON.stringify(r));
  ok(r.rows === 0,     '표는 아직 없다', JSON.stringify(r));

  console.log('\n② 누르면 표가 나온다 — 여기가 안 되던 곳');
  await pg.evaluate(() => toggleRolesGuide());
  await pg.waitForTimeout(600);
  r = await READ(pg);
  ok(r.rows > 0,      '표가 그려진다', JSON.stringify(r));
  ok(r.open === true, "'▲ 접기' 로 바뀐다", JSON.stringify(r));

  console.log('\n③ 표 안에 들어 있는 것');
  ok(r.cols.indexOf('학생') >= 0 && r.cols.indexOf('총관리') >= 0,
     '역할 칸이 학생부터 총관리까지 있다', JSON.stringify(r.cols));
  ok(r.rows >= 15, '기능 줄이 넉넉히 있다 (' + r.rows + '줄)', JSON.stringify(r));
  ok(/./.test(r.first || ''), '첫 줄에 기능 이름이 들어 있다', JSON.stringify(r.first));

  console.log('\n④ 다시 누르면 접힌다');
  await pg.evaluate(() => toggleRolesGuide());
  await pg.waitForTimeout(600);
  r = await READ(pg);
  ok(r.rows === 0,    '표가 사라진다', JSON.stringify(r));
  ok(r.shut === true, "'▼ 펼치기' 로 돌아온다", JSON.stringify(r));

  console.log('\n⑤ 왜 안 됐었나 — renderMembers() 는 다른 상자를 그린다');
  //  #member-list 는 채팅 화면 것이라 늘 문서에 있습니다. 그래서 renderMembers() 는
  //  일찍 돌아가지도 않습니다 — 그냥 **엉뚱한 상자**를 그리고 끝납니다.
  //  관리자 화면(#admin-content)은 손도 안 대니, 눌러도 조용했던 것입니다.
  const before = await pg.evaluate(() => document.getElementById('admin-content').innerText);
  const after = await pg.evaluate(async () => {
    rolesGuideOpen = true;                 // 열린 셈 치고
    await renderMembers();                 // 옛날 코드가 부르던 그것
    await new Promise(r => setTimeout(r, 300));
    const txt = document.getElementById('admin-content').innerText;
    rolesGuideOpen = false;                // 되돌려 둔다
    return txt;
  });
  ok(after === before,
     'renderMembers() 를 불러도 관리자 화면은 한 글자도 안 바뀐다 — 그래서 눌러도 조용했다',
     '바뀐 글자 수 ' + Math.abs(after.length - before.length));
  ok(r.hasChatList === true,
     '#member-list 는 채팅 쪽 상자라 늘 문서에 있다 (일찍 돌아간 게 아니었다)', JSON.stringify(r.hasChatList));

  await pg.close();
  await b.close();
  done();
})();
