//  📖 트리플스쿨 — 낸 것은 최신이 위로
//
//  '읽은 책' 을 책 목록 차례(Step · 분류)대로 늘어놓고 있었습니다.
//  칸마다 읽은 날이 적혀 있다 보니 날짜가 뒤죽박죽으로 보였습니다.
//  아직 안 읽은 책은 차례대로가 맞지만(그건 읽을 순서), 낸 것은 기록이라
//  최신이 위로 와야 합니다.
const { launch, openApp, ok, done } = require('./_harness');

//  책 목록 차례(A → B → C)와 읽은 날 차례(C → A → B)를 **일부러 어긋나게**
//  둡니다. 안 그러면 안 고쳐도 통과해 버립니다.
const BOOKS = [
  { id:'bkA', community_id:'c1', title:'AAA Book', category:'Faith', sort:1, step:1 },
  { id:'bkB', community_id:'c1', title:'BBB Book', category:'Faith', sort:2, step:1 },
  { id:'bkC', community_id:'c1', title:'CCC Book', category:'Faith', sort:3, step:1 },
];
const LOGS = [
  { id:'lgA', community_id:'c1', student_id:'s1', book_id:'bkA', read_date:'2026-05-10', report:'a', created_at:'2026-05-10T00:00:00Z' },
  { id:'lgB', community_id:'c1', student_id:'s1', book_id:'bkB', read_date:'2026-01-02', report:'b', created_at:'2026-01-02T00:00:00Z' },
  { id:'lgC', community_id:'c1', student_id:'s1', book_id:'bkC', read_date:'2026-09-30', report:'c', created_at:'2026-09-30T00:00:00Z' },
];

(async () => {
const b = await launch();

// ── ① 학생 화면 ──────────────────────────────────────────────
console.log('\n① 학생 — 읽은 책');
{
  const pg = await openApp(b, { as:'student' });   // 홍길동 = s1
  const r = await pg.evaluate(async (d) => {
    window.__DB.reading_books = d.BOOKS.slice();
    window.__DB.reading_logs  = d.LOGS.slice();
    readingLang = 'en';
    await initReadingPage();
    readingShowRead = true; readingShowUnread = true;
    renderReadingList();
    const box = document.getElementById('reading-list');
    const ids = [...box.querySelectorAll('[onclick^="openReadingLog"]')]
      .map(x => (x.getAttribute('onclick').match(/openReadingLog\('([^']+)'\)/) || [])[1]);
    return { ids, txt: box.textContent.replace(/\s+/g,' ') };
  }, { BOOKS, LOGS });

  ok(r.ids.length === 3, '읽은 책 세 권이 다 그려진다 (' + r.ids.length + ')');
  ok(JSON.stringify(r.ids) === JSON.stringify(['bkC','bkA','bkB']),
     '읽은 날 최신 순으로 놓인다 — C(9/30) → A(5/10) → B(1/2) · 지금: ' + r.ids.join(' → '));
  ok(r.ids[0] === 'bkC', '가장 최근에 낸 것이 맨 위에 있다');
  await pg.close();
}

// ── ② 날짜가 같으면 나중에 고친 것이 위로 ──────────────────────
console.log('\n② 날짜가 같을 때');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async (d) => {
    const logs = d.LOGS.map(l => ({ ...l, read_date:'2026-06-01' }));
    logs.find(l => l.book_id==='bkB').updated_at = '2026-06-05T00:00:00Z';
    logs.find(l => l.book_id==='bkA').updated_at = '2026-06-02T00:00:00Z';
    logs.find(l => l.book_id==='bkC').updated_at = '2026-06-01T00:00:00Z';
    window.__DB.reading_books = d.BOOKS.slice();
    window.__DB.reading_logs  = logs;
    readingLang = 'en';
    await initReadingPage();
    readingShowRead = true;
    renderReadingList();
    return [...document.getElementById('reading-list').querySelectorAll('[onclick^="openReadingLog"]')]
      .map(x => (x.getAttribute('onclick').match(/openReadingLog\('([^']+)'\)/) || [])[1]);
  }, { BOOKS, LOGS });
  ok(JSON.stringify(r) === JSON.stringify(['bkB','bkA','bkC']),
     '읽은 날이 같으면 나중에 고친 것이 위로 — B → A → C · 지금: ' + r.join(' → '));
  await pg.close();
}

// ── ③ 아직 안 읽은 책은 차례대로 ──────────────────────────────
console.log('\n③ 아직 안 읽은 책은 차례 그대로');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.reading_books = d.BOOKS.slice();
    window.__DB.reading_logs  = [];           // 하나도 안 읽음
    readingLang = 'en';
    await initReadingPage();
    readingShowUnread = true; readingShowRead = true;
    renderReadingList();
    return [...document.getElementById('reading-list').querySelectorAll('[onclick^="openReadingLog"]')]
      .map(x => (x.getAttribute('onclick').match(/openReadingLog\('([^']+)'\)/) || [])[1]);
  }, { BOOKS, LOGS });
  ok(JSON.stringify(r) === JSON.stringify(['bkA','bkB','bkC']),
     '안 읽은 책은 읽을 차례(A → B → C) 그대로 둔다 · 지금: ' + r.join(' → '));
  await pg.close();
}

// ── ④ 교직원이 학생 것을 볼 때 ────────────────────────────────
console.log('\n④ 교직원 — 그 학생이 읽은 책');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (d) => {
    window.__DB.reading_books = d.BOOKS.slice();
    window.__DB.reading_logs  = d.LOGS.slice();
    readingLang = 'en'; readingBooks = [];
    tcsCurrentStudent = { id:'s1', name:'홍길동', community_id:'c1', community_role:'student' };
    await renderTcsReadingUnified();
    const main = document.getElementById(tcsMainId);
    const txt = main.textContent.replace(/\s+/g,' ');
    //  읽은 책 칸은 날짜가 함께 적힌다 — 적힌 날짜 차례를 그대로 본다
    const dates = (txt.match(/2026-\d\d-\d\d/g) || []);
    return { dates, txt };
  }, { BOOKS, LOGS });

  ok(r.dates.length >= 3, '읽은 날이 세 개 이상 적힌다 (' + r.dates.length + ')');
  const first3 = r.dates.slice(0, 3);
  ok(JSON.stringify(first3) === JSON.stringify(['2026-09-30','2026-05-10','2026-01-02']),
     '교직원 화면도 최신 순 · 지금: ' + first3.join(' → '));
  await pg.close();
}

await b.close();
done();
})();
