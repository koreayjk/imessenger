//  ✏️ 활동후기 고치기 (개선창 · Christine "add an edit feature for reviews", Lisa L "I agree")
//
//  DB 는 처음부터 본인 글을 고칠 수 있게 열려 있었는데(writings_update =
//  member_id = auth.uid()), **화면에 단추가 없어서** 아무도 못 고쳤습니다.
//
//  고칠 때 질문별 칸을 되살리는 게 핵심입니다. 본문은 답을 빈 줄로 이어
//  붙인 것이라, 답 안에 빈 줄이 있으면 쪼개 되살릴 때 칸이 밀립니다.
//  그래서 저장할 때 답을 따로(final_answers) 남깁니다.
const { launch, openApp, ok, done } = require('./_harness');

const SEED = (me) => ([
  { id:'w1', member_id:me, community_id:'c1', kind:'activity', category:'선교',
    title:'필리핀 단기선교', body:'첫 답\n\n둘째 답', feedback:'숙소가 멀었어요',
    final_answers: JSON.stringify({ a:['첫 답','둘째 답'], f:['숙소가 멀었어요'] }),
    date:'2026-10-20' },
  { id:'w2', member_id:'someone-else', community_id:'c1', kind:'activity', category:'봉사활동',
    title:'남의 후기', body:'남의 글', date:'2026-10-21' },
]);

(async () => {
const b = await launch();

// ── ① 단추가 보이나 ─────────────────────────────────────────
console.log('\n① 고치기 단추');
{
  const pg = await openApp(b, { as:'student' });   // 홍길동 = s1
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed;
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 },
                                     { id:'rc2', community_id:'c1', name:'봉사활동', sort:2 }];
    writingKind = 'activity'; actEditId = null;
    await initWritingPage();
    const main = document.getElementById('writing-main');
    return {
      내글: !!main.querySelector(`[onclick^="editWriting('w1'"]`),
      남의글: !!main.querySelector(`[onclick^="editWriting('w2'"]`),
      지우기: !!main.querySelector(`[onclick^="deleteWriting('w1'"]`),
    };
  }, SEED('s1'));
  ok(r.내글, '내 후기에 ✏️ 고치기 단추가 있다');
  ok(!r.남의글, '남의 후기에는 단추가 없다');
  ok(r.지우기, '지우기 단추는 그대로 있다');
  await pg.close();
}

// ── ② 눌렀을 때 칸이 채워지나 ────────────────────────────────
console.log('\n② 칸 되살리기');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed;
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 }];
    writingKind = 'activity'; actEditId = null;
    await initWritingPage();
    editWriting('w1');
    const v = (id) => (document.getElementById(id) || {}).value;
    return {
      제목: v('wr-title'), 날짜: v('wr-date'), 분류: v('wr-cat'),
      답1: v('wr-' + ACT_QS[0].key), 답2: v('wr-' + ACT_QS[1].key),
      피드백1: v('wr-' + ACT_FB_QS[0].key),
      머리글: document.getElementById('writing-main').textContent.includes('후기 고치기'),
      취소: !!document.querySelector('[onclick^="cancelWritingEdit"]'),
      저장: !!document.querySelector('[onclick^="saveWritingEdit"]'),
      새로쓰기단추: !!document.querySelector('[onclick^="addWriting"]'),
    };
  }, SEED('s1'));
  ok(r.제목 === '필리핀 단기선교', '제목이 채워진다');
  ok(r.날짜 === '2026-10-20', '날짜가 채워진다');
  ok(r.분류 === '선교', '분류가 골라져 있다');
  ok(r.답1 === '첫 답' && r.답2 === '둘째 답', '질문별 답이 제자리에 들어간다');
  ok(r.피드백1 === '숙소가 멀었어요', '피드백도 제자리에 들어간다');
  ok(r.머리글, "머리글이 '후기 고치기' 로 바뀐다");
  ok(r.취소 && r.저장, '취소·저장 단추가 생긴다');
  ok(!r.새로쓰기단추, "고치는 중에는 '＋ 후기 저장' 이 없다 — 눌러서 새 글이 생기면 안 된다");
  await pg.close();
}

// ── ③ 고쳐 저장하면 ─────────────────────────────────────────
console.log('\n③ 고쳐 저장하기');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed;
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 }];
    writingKind = 'activity'; actEditId = null;
    await initWritingPage();
    editWriting('w1');
    document.getElementById('wr-title').value = '필리핀 단기선교 (고침)';
    document.getElementById('wr-' + ACT_QS[0].key).value = '고친 첫 답';
    document.getElementById('wr-' + ACT_FB_QS[0].key).value = '고친 피드백';
    await saveWritingEdit();
    const upd = (window.__upd || []).filter(x => x.t === 'student_writings');
    const last = upd.length ? upd[upd.length-1] : null;
    let fa = null; try { fa = JSON.parse(last.u.final_answers); } catch (_) {}
    return {
      고친곳: last && last.eq.id,
      제목: last && last.u.title,
      본문: last && last.u.body,
      피드백: last && last.u.feedback,
      답배열: fa && fa.a, 피드백배열: fa && fa.f,
      새글생겼나: (window.__ins || []).some(x => x.t === 'student_writings'),
      고치기끝: actEditId,
    };
  }, SEED('s1'));
  ok(r.고친곳 === 'w1', '그 글만 고친다');
  ok(r.제목 === '필리핀 단기선교 (고침)', '제목이 바뀐다');
  ok(/고친 첫 답/.test(r.본문 || '') && /둘째 답/.test(r.본문 || ''), '본문이 답을 이어 붙여 다시 만들어진다');
  ok(r.피드백 === '고친 피드백', '피드백도 바뀐다');
  ok(Array.isArray(r.답배열) && r.답배열[0] === '고친 첫 답', '질문별 답을 따로 남긴다 (다음에 또 고칠 수 있게)');
  ok(Array.isArray(r.피드백배열) && r.피드백배열[0] === '고친 피드백', '피드백 답도 따로 남긴다');
  ok(!r.새글생겼나, '새 글이 하나 더 생기지 않는다 — 고친 것이다');
  ok(r.고치기끝 === null, '저장하면 고치기 모드가 끝난다');
  await pg.close();
}

// ── ④ 예전 글 (final_answers 가 없던 때) ────────────────────
console.log('\n④ 예전 글도 고칠 수 있나');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async () => {
    window.__DB.student_writings = [
      { id:'old', member_id:'s1', community_id:'c1', kind:'activity', category:'선교',
        title:'옛 후기', body:'옛 첫 답\n\n옛 둘째 답', date:'2026-09-01' },
    ];
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 }];
    writingKind = 'activity'; actEditId = null;
    await initWritingPage();
    editWriting('old');
    const v = (id) => (document.getElementById(id) || {}).value;
    return { 답1: v('wr-' + ACT_QS[0].key), 답2: v('wr-' + ACT_QS[1].key), 제목: v('wr-title') };
  });
  ok(r.제목 === '옛 후기', '예전 글도 열린다');
  ok(r.답1 === '옛 첫 답' && r.답2 === '옛 둘째 답',
     'final_answers 가 없으면 빈 줄로 쪼개 되살린다 (저장하면 그다음부터는 제대로 남는다)');
  await pg.close();
}

// ── ⑤ 취소 ──────────────────────────────────────────────────
console.log('\n⑤ 취소');
{
  const pg = await openApp(b, { as:'student' });
  const r = await pg.evaluate(async (seed) => {
    window.__DB.student_writings = seed;
    window.__DB.review_categories = [{ id:'rc1', community_id:'c1', name:'선교', sort:1 }];
    writingKind = 'activity'; actEditId = null;
    await initWritingPage();
    editWriting('w1');
    cancelWritingEdit();
    return { 모드: actEditId,
             새로쓰기: !!document.querySelector('[onclick^="addWriting"]'),
             제목칸: (document.getElementById('wr-title')||{}).value };
  }, SEED('s1'));
  ok(r.모드 === null, '취소하면 고치기 모드가 풀린다');
  ok(r.새로쓰기, "'＋ 후기 저장' 단추가 돌아온다");
  ok(r.제목칸 === '', '칸이 비워진다 — 고치던 글이 새 글로 넘어가면 안 된다');
  await pg.close();
}

await b.close();
done();
})();
