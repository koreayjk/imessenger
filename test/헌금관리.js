//  🙏 헌금관리 — 예배 헌금(봉투)을 적는 자리
//
//  · 행정담당자 이상만 봅니다. 탭을 숨기는 것만으로는 모자라서 서버에서도
//    막습니다(db/헌금관리_DB설치.sql) — 그쪽은 아래 ⑥ 에서 글로 봅니다.
//  · '입출금' 과 겹치지 않습니다. 저쪽은 은행 내역, 이쪽은 봉투입니다.
const fs = require('fs'), path = require('path');
const { launch, openApp, ok, done } = require('./_harness');

const SQL = fs.readFileSync(path.join(__dirname, '..', 'db', '헌금관리_DB설치.sql'), 'utf8')
              .replace(/--[^\n]*/g, '');

const ROWS = [
  { id:'o1', community_id:'c1', date:'2026-11-02', kind:'주일헌금', member_id:'s1', donor_name:null, amount:50,  currency:'원', method:'cash',     memo:null },
  { id:'o2', community_id:'c1', date:'2026-11-02', kind:'십일조',   member_id:'s2', donor_name:null, amount:200, currency:'원', method:'check',    memo:'11월' },
  { id:'o3', community_id:'c1', date:'2026-11-09', kind:'주일헌금', member_id:null, donor_name:'박집사', amount:30, currency:'원', method:'cash',  memo:null },
  { id:'o4', community_id:'c1', date:'2026-11-09', kind:'감사헌금', member_id:null, donor_name:null,    amount:70, currency:'원', method:'cash',  memo:'무명' },
  { id:'o5', community_id:'c1', date:'2026-10-05', kind:'주일헌금', member_id:'s1', donor_name:null, amount:40,  currency:'원', method:'cash',     memo:null },
  { id:'o6', community_id:'c9', date:'2026-11-02', kind:'주일헌금', member_id:null, donor_name:'남공동체', amount:999, currency:'원', method:'cash', memo:null },
];

(async () => {
const b = await launch();

// ── ① 누가 탭을 보나 ─────────────────────────────────────────
console.log('\n① 누가 헌금 탭을 보나');
{
  const pg = await openApp(b, { as:'teacher' });   // 김선생 = community_admin
  const r = await pg.evaluate(() => {
    const keys = () => finVisibleTabs().map(x => x.key);
    const out = {};
    ME.community_role = 'community_admin'; out.관리자      = keys();
    ME.community_role = 'admin_officer';   out.행정담당자  = keys();
    ME.community_role = 'vice_admin';      out.부총관리자  = keys();
    ME.community_role = 'super_admin';     out.총관리자    = keys();
    ME.community_role = 'teacher';         out.교사        = keys();
    ME.community_role = 'staff';           out.간사        = keys();
    ME.community_role = 'student';         out.학생        = keys();
    ME.community_role = 'community_admin';
    return out;
  });
  ok(r.관리자.includes('offering'),     '관리자에게 보인다');
  ok(r.행정담당자.includes('offering'), '행정담당자에게 보인다');
  ok(r.부총관리자.includes('offering'), '부총관리자에게 보인다');
  ok(r.총관리자.includes('offering'),   '총관리자에게 보인다');
  ok(!r.교사.includes('offering'),      '교사에게는 안 보인다');
  ok(!r.간사.includes('offering'),      '간사에게는 안 보인다');
  ok(r.학생.length === 0,               '학생에게는 재정 탭 자체가 없다');
  await pg.close();
}

// ── ② 내역 · 합계 ────────────────────────────────────────────
console.log('\n② 내역과 합계');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rows) => {
    window.__DB.offerings = rows.slice();
    COMM_CUR = '$';
    finTab = 'offering'; ofMonth = '2026-11'; ofMode = 'list';
    await renderOfferingHub();
    const main = document.getElementById('school-main');
    const cards = [...main.querySelectorAll('[data-of]')].map(x => x.getAttribute('data-of'));
    return { cards, txt: main.textContent.replace(/\s+/g,' ') };
  }, ROWS);

  ok(r.cards.length === 4, '11월 것 네 건만 나온다 (' + r.cards.length + ')');
  ok(!r.cards.includes('o5'), '10월 것은 안 섞인다');
  ok(!r.cards.includes('o6'), '다른 공동체(c9) 것은 안 나온다');
  ok(/\$350/.test(r.txt.replace(/,/g,'')), '이 달 합계가 350 으로 나온다');
  ok(/홍길동/.test(r.txt) && /김하은/.test(r.txt), '멤버는 이름으로 나온다');
  ok(/박집사/.test(r.txt), '앱 밖의 분은 적어 둔 이름으로 나온다');
  ok(/무명|Anonymous/.test(r.txt), '이름 없는 건은 무명으로 나온다');
  ok(/주일헌금/.test(r.txt) && /십일조/.test(r.txt), '종류별 소계가 나온다');
  await pg.close();
}

// ── ③ 적기 ───────────────────────────────────────────────────
console.log('\n③ 헌금 적기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rows) => {
    window.__DB.offerings = rows.slice();
    COMM_CUR = '$';
    finTab = 'offering'; ofMonth = '2026-11'; ofMode = 'list';
    await renderOfferingHub();
    document.getElementById('of-new-date').value = '2026-11-16';
    document.getElementById('of-new-kind').value = '선교헌금';
    document.getElementById('of-new-who').value = 's2';
    document.getElementById('of-new-amount').value = '125.50';
    document.getElementById('of-new-method').value = 'transfer';
    document.getElementById('of-new-memo').value = '감사합니다';
    await ofAdd();
    const ins = window.__ins.filter(x => x.t === 'offerings');
    return { ins: ins.length ? ins[ins.length-1].rows[0] : null };
  }, ROWS);

  ok(!!r.ins, '저장이 실제로 일어난다');
  ok(r.ins && r.ins.community_id === 'c1', '내 공동체로 들어간다');
  ok(r.ins && r.ins.kind === '선교헌금',    '분류가 그대로 들어간다');
  ok(r.ins && r.ins.member_id === 's2',     '고른 멤버가 들어간다');
  ok(r.ins && r.ins.donor_name === null,    '멤버를 골랐으면 이름 칸은 비운다 (두 군데에 적으면 합계가 갈린다)');
  ok(r.ins && Number(r.ins.amount) === 125.5, '소수점 금액도 그대로 (' + (r.ins && r.ins.amount) + ')');
  ok(r.ins && r.ins.method === 'transfer',  '방법이 들어간다');
  ok(r.ins && r.ins.currency === '$',       '공동체 화폐로 적힌다');
  ok(r.ins && r.ins.created_by === 'me',    '적은 사람을 남긴다');
  await pg.close();
}

// ── ④ 금액 ───────────────────────────────────────────────────
console.log('\n④ 금액 지키기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rows) => {
    window.__DB.offerings = rows.slice();
    finTab = 'offering'; ofMonth = '2026-11'; ofMode = 'list';
    await renderOfferingHub();
    const before = window.__ins.filter(x => x.t === 'offerings').length;
    const tryAmt = async (v) => {
      document.getElementById('of-new-amount').value = v;
      document.getElementById('of-new-kind').value = '주일헌금';
      await ofAdd();
      return window.__ins.filter(x => x.t === 'offerings').length - before;
    };
    const zero  = await tryAmt('0');
    const empty = await tryAmt('');
    const minus = await tryAmt('-50');
    return { zero, empty, minus };
  }, ROWS);
  ok(r.zero === 0,  '0 원은 저장하지 않는다');
  ok(r.empty === 0, '빈 칸은 저장하지 않는다');
  ok(r.minus === 0, '음수는 저장하지 않는다 (빼는 건 헌금이 아니다)');
  await pg.close();
}

// ── ⑤ 사람별 합계 ────────────────────────────────────────────
console.log('\n⑤ 사람별 합계 (연말 영수증용)');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (rows) => {
    window.__DB.offerings = rows.slice();
    COMM_CUR = '$';
    finTab = 'offering'; ofYear = '2026'; ofMode = 'person';
    await renderOfferingHub();
    const main = document.getElementById('school-main');
    const names = [...main.querySelectorAll('[data-ofp]')].map(x => x.getAttribute('data-ofp'));
    return { names, txt: main.textContent.replace(/\s+/g,' ') };
  }, ROWS);

  ok(r.names.length === 3, '이름 남긴 사람 셋만 묶인다 (' + r.names.join(', ') + ')');
  ok(r.names[0] === '김하은', '많이 드린 분이 맨 위 (김하은 200)');
  ok(r.names.includes('홍길동'), '홍길동은 11월 50 + 10월 40 = 90 으로 한 줄');
  ok(!r.names.some(n => /무명|Anonymous/.test(n)), '무명은 사람별로 묶지 않는다 — 묶으면 금액만 부풀어 보인다');
  ok(/\$390/.test(r.txt.replace(/,/g,'')), '한 해 합계 390 (무명 70 포함)');
  ok(/\$320/.test(r.txt.replace(/,/g,'')), '이름 남긴 분 합계 320');
  await pg.close();
}

// ── ⑥ 설치 SQL ───────────────────────────────────────────────
console.log('\n⑥ db/헌금관리_DB설치.sql');
ok(/create table if not exists public\.offerings/.test(SQL), '표를 만든다');
ok(/alter table public\.offerings enable row level security/.test(SQL), 'RLS 를 켠다');

const rd = SQL.slice(SQL.indexOf('function public.offering_can_read'), SQL.indexOf('grant execute on function public.offering_can_read'));
ok(/'super_admin','vice_admin'/.test(rd) && /'community_admin','admin_officer'/.test(rd),
   '보기 — 총·부총관리자는 어디든, 관리자·행정담당자는 자기 공동체');
ok(!/'teacher'/.test(rd) && !/'staff'/.test(rd) && !/'student'/.test(rd),
   '교사·간사·학생은 보기 목록에 아예 없다');

const wr = SQL.slice(SQL.indexOf('function public.offering_can_write'), SQL.indexOf('grant execute on function public.offering_can_write'));
ok(/me\.community_role = 'super_admin'/.test(wr),
   '적기 — 총관리자만 공동체를 넘어 적는다');
ok(/'vice_admin','community_admin','admin_officer'/.test(wr) && /me\.community_id = cid/.test(wr),
   '나머지는 자기 공동체 안에서만 적는다 (부총관리자도)');

ok(/offerings_amount_pos/.test(SQL) && /amount > 0/.test(SQL), '금액은 0 보다 커야 한다고 DB 에도 박아 둔다');
ok(/for select to authenticated/.test(SQL) && /for insert to authenticated/.test(SQL)
   && /for update to authenticated/.test(SQL) && /for delete to authenticated/.test(SQL),
   '보기·넣기·고치기·지우기 넷 다 정책이 있다');

await b.close();
done();
})();
