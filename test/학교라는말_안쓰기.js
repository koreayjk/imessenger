//  🏫 '학교' 라는 말을 우리에게 쓰지 않기
//
//    "대한민국이 비인가 학교에서 학교라는 말을 쓸 수 없게 해뒀어
//     우리 프로그램에서 학교라는 표현 있어??"
//
//  있었습니다 — index.html 64줄. 성격이 셋으로 갈립니다.
//
//   🔴 우리가 우리를 '학교' 라 부르는 곳   → 바꿨습니다 (28곳)
//   🟡 바깥 학교를 가리키는 곳            → 그대로 (아이가 다니는 학교,
//                                          학교 와이파이, 한동대학교…)
//   🟢 법령·공식 서식 용어                → 손대면 안 됩니다
//        「학교생활기록부」「학교폭력 조치상황」「초·중·고(학교급)」
//        교육부 「학교생활기록 작성 및 관리지침」 서식 이름 그대로입니다.
//
//  ★ 여기서 재는 것 — 화면에 실제로 그려진 글을 읽습니다.
//   ① 내 프로필이 「소속 정보 / 소속 기관명」 인가
//   ② 생기부 칸이 「소속 기관명 / 기관 구분 / 대표자」 인가
//   ③ ⚠️ 기관 구분의 **고를 수 있는 값은 그대로**인가
//        — 운영 73건에 '대안학교'·'기독학교'·'기타' 가 이미 저장돼
//          있습니다. 목록에서 빼면 그 73건이 빈칸으로 보입니다.
//   ④ 예치금이 「공동체가 맡아두는 돈」 인가
//   ⑤ 증명서 칸·예시문에 '학교'·'본교' 가 없나
//   ⑥ 법령 용어는 그대로 남아 있나 (괜히 지우면 공식 서식이 아니게 된다)
const { launch, openApp, ok, done } = require('./_harness');

const KO = (ko, en) => ko;   // t() 가 한국어를 돌려주는 상황을 그대로 본다

(async () => {
const b = await launch();
const pg = await openApp(b, { as:'teacher' });

//  이름표 28곳이 index.html 곳곳에 흩어져 있습니다. 화면마다 그려
//  보려면 화면 함수 열 개를 불러야 하고, 그러다 한 군데를 빠뜨리면
//  시험이 조용히 통과합니다. 그래서 **소스 글자를 직접** 봅니다 —
//  되돌려 놓으면 반드시 ❌ 가 뜹니다 (확인했습니다).
const fs = require('fs'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');

console.log('\n① 내 프로필 — 이름표');
ok(src.includes("t('소속 정보','Affiliation')"), '「학교 정보」 가 「소속 정보」 로 바뀌었다');
ok(!src.includes("t('학교 정보','School Info')"), '「학교 정보」 가 남아 있지 않다');
ok(src.includes("t('소속 기관명','Organization'), ME.school_name"), '내 프로필의 칸이 「소속 기관명」 이다');
ok(!/예: IM선교회 대안학교/.test(src), '예시에서 「대안학교」 가 빠졌다');

console.log('\n② 생기부 칸');
ok(src.includes("label:t('소속 기관명','Organization')"), '「학교명」 → 「소속 기관명」');
ok(src.includes("label:t('기관 구분','Organization Type')"), '「학교 구분」 → 「기관 구분」');
ok(src.includes("label:t('대표자','Representative')"), '「학교장」 → 「대표자」');
ok(src.includes("row('소속 기관명'") && src.includes("row('기관 구분'"), '인쇄물 표에도 반영됐다');
ok(src.includes('<th>대표자</th>') && !src.includes('<th>학교장</th>'), '인쇄물 표 머리가 「대표자」 다');

console.log('\n③ ⚠️ 고를 수 있는 값은 그대로 — 운영 73건이 걸려 있다');
{
  const m = src.match(/\{key:'school_type',[^\n]*options:\[([^\]]*)\]/);
  ok(!!m, '기관 구분의 고르개를 찾았다');
  const opts = m ? m[1] : '';
  ok(/'대안학교'/.test(opts), "'대안학교' 가 그대로 고를 수 있다 — 저장된 것이 안 사라진다", opts);
  ok(/'기독학교'/.test(opts), "'기독학교' 도 그대로다", opts);
}

console.log('\n④ 예치금');
ok(src.includes('공동체에 맡긴 돈의 잔액과 내역이에요'), '「학교에 맡긴 돈」 → 「공동체에 맡긴 돈」');
ok(src.includes("t('공동체가 맡아두는 돈 · 입금/출금 기록','Money held by the community · deposit/withdraw record')"),
   '「학교가 맡아두는 돈」 → 「공동체가 맡아두는 돈」 (영문까지)');
ok(!/학교가 맡아두는 돈|학교에 맡긴 돈/.test(src), '옛 글이 남아 있지 않다');

console.log('\n⑤ 증명서 · 가정통신문 · 공유 링크');
ok(src.includes("t('소속 기관명 (없으면 비움)','Organization (optional)')"), '증명서 칸이 「소속 기관명」 이다');
ok(!/본교에서/.test(src), '직접입력 예시문의 「본교」 가 빠졌다 (→ 본 공동체)');
ok(src.includes('예: 위 학생은 본 공동체에서'), '「본 공동체에서」 로 바뀌었다');
ok(src.includes("t('공동체에서 가정으로','Community to home')"), '가정통신문이 「공동체에서 가정으로」 다');
ok(/공동체에 문의해 주세요/.test(src) && !/학교에 문의해 주세요/.test(src), '공유 링크 안내가 「공동체에 문의」 다');
ok(!/○○학교장/.test(src), '직인 예시의 「○○학교장」 이 빠졌다');
ok(!/학교장 직인/.test(src), '「학교장 직인」 이 빠졌다');

console.log('\n⑥ 🟢 법령·공식 서식 용어는 그대로 — 지우면 공식 서식이 아니게 된다');
ok(src.includes('학교생활기록부'), '「학교생활기록부」 는 그대로 (교육부 문서 이름)');
ok(src.includes("label:'학교폭력 조치상황'"), '「학교폭력 조치상황」 은 그대로 (공식 항목명)');
ok(src.includes("elem:'초등학교', middle:'중학교', high:'고등학교'"), '학교급(초·중·고) 은 그대로');

console.log('\n⑦ 🟡 바깥 학교를 가리키는 곳은 그대로');
ok(/학교에서 받은 과제·시험·제출기한/.test(src), '데일리의 「학교에서 받은 과제」 는 그대로 (아이가 다니는 학교)');
ok(/예: 학교 제출용/.test(src), '서류 신청의 「학교 제출용」 은 그대로 (바깥에 내는 것)');

done(b);
})();
