//  ✍️ 활동후기 — 교직원이 학생 글을 읽는 자리
//
//  왜 이 시험이 있나
//    쓰는 쪽(학생)만 만들고 읽는 쪽을 안 만들어서, 실제 DB 에 아홉 편이
//    쌓이도록 **아무도 못 보고 있었습니다.** '📣 준비한 쪽에 주는 말' 도
//    '간사·선생님만 보임' 이라고 걸어 뒀는데, 그 코드가 들어 있는 목록이
//    학생 본인 것만 불러오니(initWritingPage 의 .eq('member_id', ME.id))
//    사실상 아무에게도 안 보였습니다.
//    같은 일이 또 생기지 않게, '남의 글이 보이는지'를 화면에서 잽니다.
const { launch, openApp, ok, done } = require('./_harness');

const SEED = [
  { id:'w1', member_id:'s1', community_id:'c1', kind:'activity', category:'선교',
    title:'필리핀 단기선교', body:'아이들과 찬양을 했습니다. 처음엔 어색했는데 나중엔 손을 잡아 주었습니다.',
    feedback:'숙소에서 모이는 시간이 너무 늦어 다음날 집중이 어려웠습니다.', date:'2026-10-20' },
  { id:'w2', member_id:'s2', community_id:'c1', kind:'activity', category:'봉사활동',
    title:'요양원 봉사', body:'어르신들께 편지를 읽어 드렸습니다.', feedback:'', date:'2026-11-01' },
  { id:'w3', member_id:'s1', community_id:'c1', kind:'book',
    title:'어린 왕자', body:'여우가 길들인다는 말을 했습니다.', date:'2026-09-02' },
  { id:'w4', member_id:'s1', community_id:'c9', kind:'activity', category:'선교',
    title:'남의 공동체 글', body:'여기 보이면 안 됩니다.', date:'2026-10-25' },
];

(async () => {
const b = await launch();

// ── ① 교직원이 학생 글을 본다 ──────────────────────────────────
console.log('\n① 교직원이 학생 글을 본다');
{
  const pg = await openApp(b, { as:'teacher' });   // 김선생 = community_admin
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed.slice();
    await renderReviewHub();
    //  ⚠️ 화면 전체 글자로 재면 안 된다. '아직 안 쓴 학생' 줄에도 같은
    //     이름이 적혀 있어서, 글이 하나도 안 나와도 이름은 보인다 —
    //     되돌려 보고 ✅ 가 남아서 들켰다. 그래서 '글 묶음' 안에서만 잰다.
    const cards = [...document.querySelectorAll('#school-main [data-rv]')]
                    .map(x => x.textContent.replace(/\s+/g,' ')).join(' ||| ');
    const txt = document.getElementById('school-main').textContent.replace(/\s+/g,' ');
    return { cards, txt, 글수: document.querySelectorAll('#school-main [data-rv]').length,
             탭있나: SCHOOL_TABS.some(x => x.id === 'review') };
  }, SEED);

  ok(r.탭있나, '학사 탭 목록에 활동후기가 있다');
  ok(/홍길동/.test(r.cards), '학생 이름(홍길동)이 글 묶음 안에 나온다 — 남의 글이 보인다');
  ok(/김하은/.test(r.cards), '다른 학생(김하은)의 글도 같이 나온다');
  ok(r.글수 === 2, '활동후기 두 편이 그려진다 (' + r.글수 + ')');
  ok(/필리핀 단기선교/.test(r.cards), '제목이 나온다');
  ok(/요양원 봉사/.test(r.cards), '둘째 글의 제목도 나온다');
  ok(!/남의 공동체 글/.test(r.cards), '다른 공동체(c9) 글은 안 나온다');
  ok(!/어린 왕자/.test(r.cards), '독후감(book)은 활동후기 칸에 안 섞인다');
  ok(/준비한 쪽에 주는 말/.test(r.cards) && /숙소에서 모이는 시간/.test(r.cards),
     '📣 준비한 쪽에 주는 말(피드백)이 교직원에게 보인다 — 이게 안 보이던 자리');
  ok(/학생에게는 안 보입니다/.test(r.cards), '학생에게는 안 보인다고 적혀 있다');
  ok(/개선 의견 있음/.test(r.cards), '피드백이 달린 글에는 표가 붙는다');
  ok(/이준서/.test(r.txt), "아직 안 쓴 학생(이준서)을 알려 준다");
  await pg.close();
}

// ── ② 거르기 ─────────────────────────────────────────────────
console.log('\n② 거르기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed.slice();
    await renderReviewHub();
    const txt = () => document.getElementById('school-main').textContent.replace(/\s+/g,' ');
    const out = {};
    rvSetCat('선교');        out.분류 = txt();
    rvSetCat('');
    rvSetMonth('2026-11');   out.달   = txt();
    rvSetMonth('');
    rvSetFind('요양원');      out.찾기 = txt();
    rvSetFind('');
    rvSetKind('book');       await new Promise(r2 => setTimeout(r2, 120)); out.독후감 = txt();
    return out;
  }, SEED);

  ok(/필리핀/.test(r.분류) && !/요양원/.test(r.분류), '분류로 거르면 그 분류만 남는다');
  ok(/요양원/.test(r.달) && !/필리핀/.test(r.달),     '달로 거르면 그 달만 남는다');
  ok(/요양원/.test(r.찾기) && !/필리핀/.test(r.찾기), '찾기로 거르면 맞는 것만 남는다');
  ok(/어린 왕자/.test(r.독후감), '독후감 칸으로 넘기면 독후감이 나온다');
  await pg.close();
}

// ── ③ 펼치기·접기 ─────────────────────────────────────────────
console.log('\n③ 긴 글 펼치기');
{
  const pg = await openApp(b, { as:'teacher' });
  const long = 'ㄱ'.repeat(400);
  const r = await pg.evaluate(async (body) => {
    window.__DB.student_writings = [{ id:'w9', member_id:'s1', community_id:'c1',
      kind:'activity', category:'선교', title:'긴 글', body, date:'2026-10-10' }];
    await renderReviewHub();
    const len0 = document.getElementById('school-main').textContent.length;
    rvToggle('w9');
    const len1 = document.getElementById('school-main').textContent.length;
    return { len0, len1 };
  }, long);
  ok(r.len0 < r.len1 - 200, '접혀 있다가 펼치면 본문이 다 나온다 (' + r.len0 + ' → ' + r.len1 + ')');
  await pg.close();
}

// ── ④ 학생 화면은 그대로 ───────────────────────────────────────
console.log('\n④ 학생 화면은 그대로');
{
  const pg = await openApp(b, { as:'student' });   // 홍길동 = s1
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed.slice();
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 }];
    writingKind = 'activity';
    await initWritingPage();
    return document.getElementById('writing-main').textContent.replace(/\s+/g,' ');
  }, SEED);
  ok(/필리핀 단기선교/.test(r), '학생은 자기 글을 본다');
  ok(!/요양원 봉사/.test(r),    '학생에게 남의 글은 안 보인다');
  await pg.close();
}

await b.close();
done();
})();
