//  👤 멤버 카드 — 소속과 이메일
//
//    "여기에 소속, 이메일도 넣어줘"
//
//  · 소속 : 🌐 방에서 온 사람은 community_name, 우리 공동체 사람은 COMM_NAME
//  · 이메일 : 눌러서 메일을 쓸 수 있게 mailto 로
//  · 없으면 그 줄을 아예 안 내놓는다 (빈 칸을 보여줄 이유가 없다)
const { launch, openApp, ok, done } = require('./_harness');

const read = `() => {
  const box = document.querySelector('.member-card-pop');
  if (!box) return { none: true };
  const mail = box.querySelector('[data-mc-email]');
  return {
    txt: box.innerText,
    info: !!box.querySelector('[data-mc-info]'),
    comm: (box.querySelector('[data-mc-comm]')||{}).textContent || '',
    email: mail ? mail.textContent : '',
    href: mail ? mail.getAttribute('href') : '',
  };
}`;

(async () => {
const b = await launch();

// ── ① 우리 공동체 사람 ───────────────────────────────────────
console.log('\n① 우리 공동체 사람');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((rd) => {
    COMM_NAME = 'IM HQ';
    members['x1'] = { id:'x1', name:'유은혜', community_id: CID(),
                      community_role:'community_admin', email:'eunhye@example.com' };
    openMemberCard('x1');
    const out = eval(rd)();
    closeMemberCard();
    return out;
  }, read);
  ok(r.info, '소속·이메일 자리가 생긴다');
  ok(r.comm === 'IM HQ', '소속에 지금 공동체 이름이 들어간다');
  ok(r.email === 'eunhye@example.com', '이메일이 보인다');
  ok(r.href === 'mailto:eunhye@example.com', '눌러서 메일을 쓸 수 있다');
  ok(/관리자/.test(r.txt), '직책도 그대로 있다');
  await pg.close();
}

// ── ② 🌐 방에서 온 다른 공동체 사람 ──────────────────────────
console.log('\n② 다른 공동체 사람');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((rd) => {
    COMM_NAME = 'IM HQ';
    members['u1'] = { id:'u1', name:'미국학생', community_id:'c9',
                      community_role:'student', community_name:'IM USA',
                      email:'usa@example.com' };
    openMemberCard('u1');
    const out = eval(rd)();
    closeMemberCard();
    return out;
  }, read);
  ok(r.comm === 'IM USA',
     '다른 공동체 사람은 그 사람의 공동체가 나온다 ← 내 공동체가 아니다');
  ok(r.email === 'usa@example.com', '이메일도 나온다');
  await pg.close();
}

// ── ③ 없으면 안 내놓는다 ─────────────────────────────────────
console.log('\n③ 없을 때');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((rd) => {
    const out = {};
    COMM_NAME = '';
    //  소속도 이메일도 없다
    members['n1'] = { id:'n1', name:'이름만', community_id:'c9', community_role:'student' };
    openMemberCard('n1'); out.none = eval(rd)(); closeMemberCard();
    //  이메일만 없다
    COMM_NAME = 'IM HQ';
    members['n2'] = { id:'n2', name:'메일없음', community_id: CID(), community_role:'student' };
    openMemberCard('n2'); out.noMail = eval(rd)(); closeMemberCard();
    //  소속만 없다
    COMM_NAME = '';
    members['n3'] = { id:'n3', name:'소속없음', community_id:'c9', community_role:'student',
                      email:'only@example.com' };
    openMemberCard('n3'); out.noComm = eval(rd)(); closeMemberCard();
    return out;
  }, read);
  ok(!r.none.info, '둘 다 없으면 그 자리를 아예 안 만든다');
  ok(/이름만/.test(r.none.txt), '그래도 카드는 그대로 뜬다');
  ok(r.noMail.info && r.noMail.comm === 'IM HQ' && r.noMail.email === '',
     '이메일만 없으면 소속 줄만 나온다');
  ok(r.noComm.info && r.noComm.comm === '' && r.noComm.email === 'only@example.com',
     '소속만 없으면 이메일 줄만 나온다');
  await pg.close();
}

// ── ④ 이상한 글자가 그대로 들어가지 않는다 ───────────────────
console.log('\n④ 이상한 글자');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate((rd) => {
    COMM_NAME = '<img src=x onerror=alert(1)>';
    members['h1'] = { id:'h1', name:'해커', community_id: CID(), community_role:'student',
                      email:'"><script>alert(1)</script>@x.com' };
    openMemberCard('h1');
    const box = document.querySelector('.member-card-pop');
    const out = { imgs: box.querySelectorAll('img').length,
                  scripts: box.querySelectorAll('script').length,
                  comm: eval(rd)().comm };
    closeMemberCard();
    return out;
  }, read);
  ok(r.imgs === 0 && r.scripts === 0, '글자가 그대로 코드로 들어가지 않는다');
  ok(r.comm === '<img src=x onerror=alert(1)>', '글자 그대로 글자로 보인다');
  await pg.close();
}

await b.close();
done();
})();
