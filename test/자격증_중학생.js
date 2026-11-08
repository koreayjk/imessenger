//  📜 자격증 — 중학생도 쓸 수 있게 (개선창 · 김환경 간사 · 어웨이크닝)
//
//    "자격증 기입이 현재 고등학생만 되는것 같습니다. 자격증 칸이
//     저학년도 기입할수 있게 설정되면 좋겠습니다. 중학생들 자격증
//     이수한게 있는데 추가하려고 보니 고등학생만 되어서요"
//
//  교육부 서식에는 자격증·NCS 가 **고등학교에만** 있습니다. 그래서
//  levels:['high'] 였습니다. 중학교에도 엽니다 — 다만 공식 서식에
//  없는 학교급이라는 것은 그 화면에 적어 둡니다. 모르고 공식 서류인
//  줄 알면 안 됩니다.
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();

// ── ① 학년별로 어떤 항목이 보이나 ───────────────────────────
console.log('\n① 학년별 항목');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => {
    const has = (g, id) => tcsSectionsFor(g).some(s => s.id === id);
    return {
      certs:  { K:has(0,'certs'), G3:has(3,'certs'), G7:has(7,'certs'),
                G9:has(9,'certs'), G10:has(10,'certs'), G12:has(12,'certs') },
      awards: { G3:has(3,'awards'), G7:has(7,'awards') },
      free:   { G7:has(7,'freesem'), G10:has(10,'freesem') },
      unknown: tcsSectionsFor(null).some(s => s.id === 'certs'),
    };
  });
  await pg.close();
  ok(r.certs.G7 && r.certs.G9, '중학생(7·9학년)에게 자격증 칸이 열린다 ← 이게 요청이었다');
  ok(r.certs.G10 && r.certs.G12, '고등학생은 전과 같이 열린다');
  ok(!r.certs.K && !r.certs.G3, '초등학생에게는 열지 않는다 (요청은 중학생이었다)');
  ok(!r.awards.G3 && r.awards.G7, '수상경력은 전과 같다 — 초등 없음·중등 있음');
  ok(r.free.G7 && !r.free.G10, '자유학기는 전과 같다 — 중등만');
  ok(r.unknown, '학년을 모르면 다 보여준다 (전과 같다)');
}

// ── ② 학년 숫자 읽기 ────────────────────────────────────────
console.log('\n② 학년 숫자 읽기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => ({
    K: tcsGradeNum({ grade:'K' }), k: tcsGradeNum({ grade:'k' }),
    G7: tcsGradeNum({ grade:'G7' }), n9: tcsGradeNum({ grade:'9' }),
    sp: tcsGradeNum({ grade:' G10 ' }),
    none: tcsGradeNum({ grade:'' }), nil: tcsGradeNum(null),
    junk: tcsGradeNum({ grade:'모름' }),
  }));
  await pg.close();
  ok(r.K === 0 && r.k === 0, 'K 는 0 으로 읽는다 (대소문자 모두)');
  ok(r.G7 === 7 && r.n9 === 9 && r.sp === 10, 'G7 · 9 · 띄어쓴 G10 을 읽는다');
  ok(r.none === null && r.nil === null && r.junk === null,
     '빈 값·없음·글자는 null — 그래야 "다 보여주기"로 간다');
}

// ── ③ 중학생 화면에 안내가 뜬다 ─────────────────────────────
console.log('\n③ 안내 문구');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    const out = {};
    document.getElementById('tcs-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="tcs-main"></div>');
    tcsMainId = 'tcs-main';
    for (const [key, grade] of [['middle','G8'], ['high','G11']]) {
      tcsCurrentStudent = { id:'s1', name:'아이', grade };
      tcsListDraft = { section:'certs', entries:[] };
      renderListEditor();
      const el = document.getElementById('tcs-main');
      out[key] = { note: !!el.querySelector('[data-lv-note]'), txt: el.innerText };
    }
    //  다른 항목에는 안 뜬다
    tcsCurrentStudent = { id:'s1', name:'아이', grade:'G8' };
    tcsListDraft = { section:'awards', entries:[] };
    renderListEditor();
    out.awards = !!document.getElementById('tcs-main').querySelector('[data-lv-note]');
    return out;
  });
  await pg.close();
  ok(r.middle.note, '중학생에게는 안내가 뜬다');
  ok(/고등학교에만/.test(r.middle.txt),
     '공식 서식에는 고등학교에만 있다고 알려준다 ← 공식 서류인 줄 알면 안 된다');
  ok(/우리 공동체 기록/.test(r.middle.txt), '우리 공동체 기록이라고 적어준다');
  ok(!r.high.note, '고등학생에게는 안 뜬다 (원래 그 학교급 항목이다)');
  ok(!r.awards, '다른 항목에는 안 뜬다');
}

await b.close();
done();
})();
