//  📄 증명서 — 재학증명서 내리고, 학비 납입 → 기부금 납입
//
//    "증명서에서 재학증명서를 없애주고
//     학비납입증명서를 기부금 납입 증명서로 바꿔줘
//     대한민국이 비인가 학교에서 학교라는 말을 쓸 수 없게 해뒀어"
//
//  재학증명서는 정의를 **지우지 않고** retired 로 표시만 했습니다.
//  운영 DB 에 이미 발급한 것이 4건, 신청 기록이 2건 있어서, 통째로
//  지우면 지난 기록의 이름이 'enroll' 같은 열쇠로 깨져 보입니다.
//
//  ★ 여기서 재는 것
//   ① 발급 화면 고르개에 재학증명서가 없나
//   ② 학부모·학생 신청 고르개에도 없나
//   ③ 지난 기록(재학증명서)의 이름은 그대로 보이나
//   ④ 학비 → 기부금으로 이름·본문이 바뀌었나
//   ⑤ 옛 기록을 열어 재학증명서가 골라진 상태면, 그때는 고르개에 보이나
//      (안 보이면 브라우저가 엉뚱한 종류로 튀어 다른 증명서가 나간다)
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();
const pg = await openApp(b, { as:'teacher' });

//  화면을 **실제로 그려서** 고르개를 읽습니다. 거르는 식을 시험 안에
//  베껴 쓰면, index.html 을 되돌려 놔도 시험은 통과해 버립니다.
const drawIssue = (pg, ty) => pg.evaluate((ty) => {
  certLang = 'ko'; certType = ty; certStudentId = null;
  certPrefill = { name:'', birth:'', school:'', address:'' };
  if (!document.getElementById('school-main'))
    document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
  renderCert();
  const sel = document.getElementById('cert-type');
  return {
    keys: [...sel.options].map(o => o.value),
    labels: [...sel.options].map(o => o.textContent),
    value: sel.value,
  };
}, ty);

// ── ① 발급 화면 고르개 ───────────────────────────────────────
console.log('\n① 발급 화면 — 증명서 종류 고르개 (그려서 읽습니다)');
{
  const d = await drawIssue(pg, 'admit');
  const r = d.keys.map((k, i) => k + '=' + d.labels[i]);
  ok(!r.some(x => x.startsWith('enroll=')), '재학증명서가 고르개에 없다', r.join(' · '));
  ok(r.some(x => x === 'tuition_paid=기부금 납입 증명서'), '기부금 납입 증명서가 있다', r.join(' · '));
  ok(!r.some(x => x.includes('학비')), '「학비」 라는 이름이 하나도 없다');
}

// ── ② 학부모·학생 신청 고르개 ────────────────────────────────
console.log('\n② 학부모·학생이 신청하는 자리');
{
  const r = await pg.evaluate(() => {
    APP_LANG = 'ko';
    document.body.insertAdjacentHTML('beforeend',
      '<div id="t-child">' + childCertHtml({ id:'s1', name:'홍길동', community_id:'c1' }, []) + '</div>');
    const sel = document.querySelector('#t-child #child-cert-kind');
    const out = {
      kinds: CHILD_CERT_KINDS.slice(),
      keys: [...sel.options].map(o => o.value),
      shown: [...sel.options].map(o => o.textContent),
    };
    document.getElementById('t-child').remove();
    return out;
  });
  ok(!r.kinds.includes('enroll'), '신청 목록에 enroll 이 없다', r.kinds.join(','));
  ok(!r.keys.includes('enroll'), '그려 놓은 고르개에도 enroll 이 없다', r.keys.join(','));
  ok(!r.shown.some(x => x.includes('재학')), '신청 고르개에 재학증명서가 없다', r.shown.join(' · '));
  ok(r.shown.includes('기부금 납입 증명서'), '기부금 납입 증명서는 신청할 수 있다', r.shown.join(' · '));
}

// ── ③ 지난 기록의 이름 ──────────────────────────────────────
console.log('\n③ 이미 발급된 재학증명서 — 이름이 깨지지 않아야 합니다');
{
  const r = await pg.evaluate(() => {
    certLang = 'ko';
    return { kept: certKindLabel('enroll', ''), doc: CERT_TYPES.enroll && CERT_TYPES.enroll.ko.docLabel };
  });
  ok(r.kept === '재학증명서', '대장에 「재학증명서」 로 그대로 보인다', r.kept);
  ok(r.doc === '재 학 증 명 서', '다시 뽑아도 문서 제목이 그대로다', r.doc);
}

// ── ④ 학비 → 기부금 ────────────────────────────────────────
console.log('\n④ 증서에 찍히는 글');
{
  const r = await pg.evaluate(() => {
    const ko = CERT_TYPES.tuition_paid.ko, en = CERT_TYPES.tuition_paid.en;
    return { doc: ko.docLabel, stmt: ko.stmt, sub: ko.sub, enL: en.label, enS: en.stmt };
  });
  ok(r.doc === '기 부 금 납 입 증 명 서', '문서 제목이 기부금이다', r.doc);
  ok(r.stmt.includes('기부금') && !r.stmt.includes('학비'), '본문이 기부금이다', r.stmt);
  ok(!/TUITION/i.test(r.sub + r.enL + r.enS), '영문에도 tuition 이 없다', r.sub + ' / ' + r.enL);
  ok(/[Dd]onation/.test(r.enL) && /donation/i.test(r.enS), '영문은 donation 이다', r.enL + ' / ' + r.enS);
}

// ── ⑤ 옛 기록을 열었을 때 ───────────────────────────────────
console.log('\n⑤ 옛 재학증명서를 열어 둔 채 화면을 그릴 때');
{
  const d = await drawIssue(pg, 'enroll');
  ok(d.keys.includes('enroll'), '그 한 번은 고르개에 보인다 — 다른 증명서로 튀지 않는다', d.keys.join(','));
  ok(d.value === 'enroll', '골라진 채로 그려진다 — 재발급 때 다른 증명서가 나가지 않는다', d.value);
}

done(b);
})();
