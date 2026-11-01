//  ✍️ 활동 후기 — 질문에 답하면 한 편의 글이 되는가
//
//  빈 칸 하나를 내밀면 아이들은 '재밌었다' 로 끝냅니다. 그래서 질문을
//  줍니다. 다만 **저장된 글에는 질문이 남으면 안 됩니다** — 답만 이어
//  붙여도 앞뒤가 이어지도록 질문을 짰습니다.
//
//  그리고 후기와 따로, **준비한 쪽에 주는 말**을 받습니다. 이건 간사
//  이상만 봅니다. 아이들끼리 서로 보면 솔직한 말이 안 나옵니다.
const { launch, openApp, ok, done } = require('./_harness.js');

const CATS = [
  { id:'rc1', community_id:'c1', name:'선교',    sort:1 },
  { id:'rc2', community_id:'c1', name:'봉사활동', sort:2 },
  { id:'rc3', community_id:'c1', name:'우리학교만의분류', sort:50 },
];

//  활동 후기 화면을 연다
async function openReview(pg, lang) {
  await pg.evaluate((lg) => {
    if (lg) APP_LANG = lg;
    document.getElementById('app').style.display = 'none';
    const v = document.getElementById('writing-view');
    v.style.display = 'flex';
    writingKind = 'activity';
    writingEntries = [];
    renderWriting();
  }, lang || null);
  //  앞선 저장이 initWritingPage() 로 화면을 다시 그리는 중일 수 있다.
  //  그 뒤에 값을 넣어야 한다 — 안 그러면 넣자마자 지워진다.
  await pg.waitForTimeout(500);
}

const boxes = (pg) => pg.evaluate(() => {
  const all = [...document.querySelectorAll('#writing-main textarea')].map(x => x.id);
  return { all, body: !!document.getElementById('wr-body'),
           txt: document.getElementById('writing-main').textContent.replace(/\s+/g, ' ') };
});

(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'student' });
  //  ⚠️ 저장하면 initWritingPage() 가 분류를 **다시 읽어 옵니다.** 변수에만
  //     넣어 두면 그때 빈 목록으로 덮여서, 두 번째 저장이 '분류를 고르세요'
  //     로 막힙니다 (재 보고 알았습니다). 가짜 표에도 넣어 둡니다.
  await pg.evaluate((c) => { reviewCats = c; window.__DB.review_categories = c; }, CATS);
  await openReview(pg);

  // ── 질문이 있는가 ───────────────────────────────────────────────
  const bx = await boxes(pg);
  ok(!bx.body, '빈 칸 하나만 내밀지 않는다');
  ok(bx.all.filter(x => /^wr-a\d$/.test(x)).length === 6, '후기 질문이 여섯 개다');
  ok(bx.all.filter(x => /^wr-f\d$/.test(x)).length === 4, '피드백 질문이 네 개다');
  ok(/어디에, 언제, 누구와 다녀왔나요/.test(bx.txt), '첫 질문이 도입을 연다');
  ok(/앞으로 어떻게 해보고 싶나요/.test(bx.txt), '마지막 질문이 마무리를 짓는다');
  ok(/질문은 빠지고 쓴 글만/.test(bx.txt), '질문이 빠진다고 미리 알려 준다');
  ok(/간사·선생님만 봅니다/.test(bx.txt), '피드백은 누가 보는지 적어 둔다');

  //  ⚠️ 질문이 '앞에서 말한…' 처럼 서로를 가리키면, 질문을 빼는 순간
  //     글이 말이 안 됩니다. 각 답이 제 발로 서야 합니다.
  const lean = await pg.evaluate(() => ACT_QS.map(x => x.q).join(' '));
  ok(!/앞에서|위에서|다음 질문|아래|이어서/.test(lean), '질문이 서로를 가리키지 않는다 (빼도 글이 선다)');

  // ── 답만 남는가 ─────────────────────────────────────────────────
  await pg.evaluate(() => {
    document.getElementById('wr-title').value = '멕시코 단기선교';
    document.getElementById('wr-a1').value = '지난 7월, 교회 친구들과 멕시코에 다녀왔다.';
    document.getElementById('wr-a2').value = '솔직히 가기 전에는 더위가 걱정됐다.';
    document.getElementById('wr-a3').value = '';                       // 빈칸
    document.getElementById('wr-a4').value = '아이들이 먼저 손을 내밀었다.';
    document.getElementById('wr-a6').value = '우리 동네에서도 해보고 싶다.';
    addWriting();
  });
  await pg.waitForTimeout(400);
  const ins = await pg.evaluate(() => (window.__ins.find(x => x.t === 'student_writings') || {}).rows || []);
  const row = ins[0] || {};
  console.log('     저장된 글:', JSON.stringify(row.body));
  ok(!!row.body, '글이 저장된다');
  ok(!/①|②|어디에, 언제/.test(row.body || ''), '저장된 글에 질문이 남지 않는다');
  ok((row.body || '').split('\n\n').length === 4, '빈칸은 빼고 답만 이어 붙인다 (4칸)');
  ok((row.body || '').startsWith('지난 7월'), '첫 답이 첫 문장이 된다');
  ok((row.body || '').endsWith('해보고 싶다.'), '마지막 답이 마지막 문장이 된다');
  ok(row.feedback === undefined, '피드백을 안 썼으면 아예 안 보낸다');

  // ── 피드백 ──────────────────────────────────────────────────────
  await openReview(pg);
  await pg.evaluate(() => {
    window.__ins = [];
    document.getElementById('wr-a1').value = '봉사활동에 다녀왔다.';
    document.getElementById('wr-f2').value = '출발 시간이 두 번 바뀌어서 기다리는 사람이 많았다.';
    document.getElementById('wr-f3').value = '나였다면 전날 밤에 한 번 더 알렸을 것이다.';
    addWriting();
  });
  await pg.waitForTimeout(400);
  const row2 = (await pg.evaluate(() => (window.__ins.find(x => x.t === 'student_writings') || {}).rows || []))[0] || {};
  console.log('     피드백:', JSON.stringify(row2.feedback));
  ok(!!row2.feedback, '피드백을 따로 담는다');
  ok(!/①|②/.test(row2.feedback || ''), '피드백에도 질문이 남지 않는다');
  ok(!/출발 시간/.test(row2.body || ''), '피드백이 후기 본문에 섞이지 않는다');

  //  질문이 비판적으로 묻는가 — '좋았어요' 로 끝나면 다음이 나아지지 않는다
  const fq = await pg.evaluate(() => ACT_FB_QS.map(x => x.q + ' ' + x.hint).join(' '));
  ok(/왜 그렇게 생각하나요/.test(fq), '잘 된 것도 까닭을 묻는다');
  ok(/무엇 때문이었을까요/.test(fq), '아쉬운 것의 원인을 묻는다');
  ok(/다르게 했을까요/.test(fq), '대안을 묻는다');
  ok(/무엇이 좋아질까요/.test(fq), '바꾸면 무엇이 나아지는지까지 묻는다');
  ok(/사람을 탓하지 말고/.test(fq), '사람이 아니라 일을 보라고 이른다');

  // ── 칸이 아직 없는 데이터베이스 ─────────────────────────────────
  //  후기까지 통째로 잃으면 안 된다. 글은 살리고 까닭을 말한다.
  await openReview(pg);
  await pg.evaluate(() => {
    window.__ins = [];
    //  처음 한 번만 실패시킨다 — 피드백을 뺀 두 번째 시도는 통과해야 한다
    window.__err = { table:'student_writings', times: 1,
                     e:{ message:"Could not find the 'feedback' column of 'student_writings'", code:'PGRST204' } };
    document.getElementById('wr-a1').value = '수련회에 다녀왔다.';
    document.getElementById('wr-f1').value = '찬양 시간이 좋았다. 다 같이 불렀기 때문이다.';
    addWriting();
  });
  await pg.waitForTimeout(600);
  const after = await pg.evaluate(() => ({
    rows: (window.__ins.find(x => x.t === 'student_writings') || {}).rows || [],
    txt: document.body.textContent,
  }));
  ok(after.rows.length === 1, '칸이 없어도 후기는 저장된다');
  ok(after.rows[0].feedback === undefined, '피드백은 빼고 다시 넣는다');
  ok(/활동후기_피드백_DB설치\.sql/.test(after.txt), '왜 피드백이 안 담겼는지 알려 준다');
  await pg.evaluate(() => { window.__err = null; });

  // ── 누가 보는가 ─────────────────────────────────────────────────
  const seeAs = async (who) => {
    const p2 = await openApp(b, { as: who });
    await p2.evaluate((c) => { reviewCats = c; window.__DB.review_categories = c; }, CATS);
    await p2.evaluate(() => {
      document.getElementById('app').style.display = 'none';
      document.getElementById('writing-view').style.display = 'flex';
      writingKind = 'activity';
      writingEntries = [{ id:'w1', member_id:'s9', kind:'activity', category:'선교',
                          title:'남이 쓴 후기', body:'다녀왔다.', date:'2026-10-01',
                          feedback:'출발 시간이 두 번 바뀌었다.' }];
      renderWriting();
    });
    await p2.waitForTimeout(250);
    const txt = await p2.evaluate(() => document.getElementById('writing-main').textContent);
    await p2.close();
    return txt;
  };
  const asTeacher = await seeAs('teacher');
  ok(/출발 시간이 두 번 바뀌었다/.test(asTeacher), '간사·선생님은 피드백을 본다');
  ok(/준비한 쪽에 주는 말/.test(asTeacher), '무엇인지 이름을 붙여 보여 준다');
  const asStudent = await seeAs('student');
  ok(!/출발 시간이 두 번 바뀌었다/.test(asStudent), '다른 학생에게는 피드백이 안 보인다');
  ok(/다녀왔다/.test(asStudent), '후기 본문은 그대로 보인다');

  // ── 영어로 볼 때 ────────────────────────────────────────────────
  //  분류 이름은 데이터베이스에 한글로 들어 있어서, 영어로 봐도 한글로 나왔다
  await openReview(pg, 'en');
  const en = await pg.evaluate(() => {
    const sel = document.getElementById('wr-cat');
    return { opts: [...sel.options].map(o => o.text).join(' | '),
             vals: [...sel.options].map(o => o.value).join(' | ') };
  });
  console.log('     영어로 본 분류:', en.opts);
  ok(/Mission/.test(en.opts) && /Volunteering/.test(en.opts), '기본 분류가 영어로 나온다');
  ok(!/선교|봉사활동/.test(en.opts), '영어로 볼 때 한글이 안 섞인다');
  ok(/우리학교만의분류/.test(en.opts), '직접 넣은 분류는 적힌 그대로 둔다');
  ok(/선교/.test(en.vals), '저장되는 값은 한글 그대로다 (바꾸면 지난 기록과 어긋난다)');

  await openReview(pg, 'ko');
  ok(/선교/.test((await pg.evaluate(() => document.getElementById('wr-cat').innerHTML))), '한글로 보면 한글로 나온다');

  await pg.close(); await b.close(); done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
