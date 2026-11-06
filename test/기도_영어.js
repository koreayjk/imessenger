//  🤲 영어판에서 기도 화면만 한글로 남아 있던 것
//
//  Lisa L (IM USA) 가 올린 개선창 글:
//    "In the english version of TCS, the 'prayer' bottom is in Korean.
//     Other parts are all English"
//
//  머리글 · 빈 화면 · 사람 수 · 버튼 · 올리는 창 · 날짜가 전부 한글로
//  박혀 있었습니다. 영어로 쓰시는 분에게는 그 화면만 통째로 외국어입니다.
const { launch, openApp, ok, done } = require('./_harness');

//  화면에 한글이 남았는지 — 사람이 적은 글(제목·이름·그룹 이름)은 빼고 본다
const HANGUL = /[가-힣]/;

(async () => {
const b = await launch();

// ── ① 영어로 보기 ────────────────────────────────────────────
console.log('\n① 영어판 기도 화면');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    APP_LANG = 'en';
    try { applyI18n(); } catch (_) {}
    window.__DB.prayers = [
      { id:'pr1', community_id:'c1', member_id:'s1', member_name:'Christine',
        title:'Exam week', body:'Please pray', scope:'전체', prayer_count:3,
        created_at:'2026-11-01T00:00:00Z' },
    ];
    prayerJoined = {};
    await loadPrayers();
    renderPrayerContent();
    renderPrayerPanel();
    const head = document.getElementById('prayer-view');
    const area = document.getElementById('prayer-list');
    return {
      머리글: head ? head.querySelector('.chat-header-name').textContent.trim() : '',
      설명:  head ? head.querySelector('.chat-header-desc').textContent.trim() : '',
      올리기: head ? head.querySelector('[onclick^="showPrayerForm"]').textContent.trim() : '',
      본문: area ? area.textContent.replace(/\s+/g,' ').trim() : '',
    };
  });

  ok(!HANGUL.test(r.머리글), '머리글이 영어다 — "' + r.머리글 + '"');
  ok(!HANGUL.test(r.설명),  '설명도 영어다 — "' + r.설명 + '"');
  ok(!HANGUL.test(r.올리기), '올리기 단추도 영어다 — "' + r.올리기 + '"');
  ok(!HANGUL.test(r.본문),  '카드에 한글이 안 남는다 — "' + r.본문.slice(0,90) + '"');
  ok(/Everyone/.test(r.본문), "범위 '전체' 가 Everyone 으로 나온다 (저장값은 그대로 한글)");
  ok(/praying together/i.test(r.본문), "'함께 기도 중' 이 영어로 나온다");
  ok(!/3명/.test(r.본문), "사람 수에 '명' 이 안 붙는다");
  await pg.close();
}

// ── ② 올리는 창 ──────────────────────────────────────────────
console.log('\n② 올리는 창');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    APP_LANG = 'en';
    window.__DB.prayers = [];
    await loadPrayers(); renderPrayerContent();
    await showPrayerForm();
    const card = document.querySelector('#prayer-list .prayer-card');
    return {
      글: card ? card.textContent.replace(/\s+/g,' ').trim() : '(창이 안 열림)',
      제목칸: (document.getElementById('ptitle')||{}).placeholder || '',
      내용칸: (document.getElementById('pbody')||{}).placeholder || '',
    };
  });
  ok(!HANGUL.test(r.글), '올리는 창에 한글이 안 남는다 — "' + r.글.slice(0,80) + '"');
  ok(!HANGUL.test(r.제목칸) && !HANGUL.test(r.내용칸),
     '입력칸 안내말도 영어다 — "' + r.제목칸 + '" / "' + r.내용칸.slice(0,40) + '"');
  await pg.close();
}

// ── ③ 한글판은 그대로 ────────────────────────────────────────
console.log('\n③ 한글판은 건드리지 않았다');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    APP_LANG = 'ko';
    try { applyI18n(); } catch (_) {}
    window.__DB.prayers = [
      { id:'pr1', community_id:'c1', member_id:'s1', member_name:'홍길동',
        title:'시험 주간', body:'기도 부탁드려요', scope:'전체', prayer_count:3,
        created_at:'2026-11-01T00:00:00Z' },
    ];
    prayerJoined = {};
    await loadPrayers(); renderPrayerContent();
    const area = document.getElementById('prayer-list');
    return { 본문: area.textContent.replace(/\s+/g,' ').trim(),
             머리글: document.querySelector('#prayer-view .chat-header-name').textContent.trim() };
  });
  ok(r.머리글 === '기도제목', '한글 머리글은 그대로다');
  ok(/전체/.test(r.본문) && !/Everyone/.test(r.본문), "한글판에서는 '전체' 그대로 나온다");
  ok(/3명/.test(r.본문), "한글판은 '3명' 으로 센다");
  ok(/함께 기도 중/.test(r.본문), "한글판 '함께 기도 중' 그대로");
  await pg.close();
}

// ── ④ 언어를 바꾸면 빠른 한 마디도 따라온다 ──────────────────
console.log('\n④ 도중에 언어를 바꿨을 때');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    APP_LANG = 'ko'; const ko = prayerQuick().map(x => x[1]).join(' | ');
    APP_LANG = 'en'; const en = prayerQuick().map(x => x[1]).join(' | ');
    return { ko, en };
  });
  ok(HANGUL.test(r.ko), '한글일 때는 한글 — "' + r.ko.slice(0,30) + '"');
  ok(!HANGUL.test(r.en),
     '영어로 바꾸면 빠른 한 마디도 영어가 된다 (const 배열이면 처음 말로 굳는다) — "' + r.en.slice(0,40) + '"');
  await pg.close();
}

await b.close();
done();
})();
