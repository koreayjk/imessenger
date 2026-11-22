//  📺 사용법 강의 — 운영관리 ▸ 사역자 교육 **왼쪽** 칸
//
//  TCS 사용법 10강을 공동체 안에서 보는 자리입니다. 영상은 유튜브에 있고
//  여기는 주소만 모아 둡니다. 주소는 app_settings 에 — 강의는 공동체마다
//  다른 것이 아니라 모두가 같은 열 개를 보기 때문입니다.
//
//  재는 것:
//   ① 칸이 사역자 교육 **바로 왼쪽** 에 있나 (옆에 놓으라고 하신 자리)
//   ② 주소가 없는 강은 **눌리지 않나** (눌러도 아무 일 없으면 고장으로 보입니다)
//   ③ 주소를 넣은 강만 열리고, 임베드에 **그 강의 영상 id** 가 들어가나
//   ④ 주소 넣는 칸이 **총관리자에게만** 보이나
//   ⑤ 저장하면 app_settings 에 JSON 으로 들어가나
//   ⑥ 규칙(RLS)에 막혀 0건이면 **저장했다고 거짓말하지 않나**
const { launch, openApp, ok, done } = require('./_harness');

const U1  = 'https://youtu.be/aaaaaaaaaaa';
const U5  = 'https://www.youtube.com/watch?v=bbbbbbbbbbb';
const PLS = 'https://www.youtube.com/playlist?list=PLxxxx';

async function setup(b, role, links) {
  const pg = await openApp(b, { as: 'teacher' });
  await pg.evaluate(([role, links]) => {
    ME.community_role = role;
    window.__DB['app_settings'] = links
      ? [{ key: 'guide_lecture_links', value: JSON.stringify(links) }]
      : [];
    //  화면을 여는 자리와 상태를 처음으로 되돌린다
    schoolSection = 'ops'; schoolSubMode = 'lecture';
    guideLinks = null; guideSel = null; guideEdit = false;
    document.getElementById('school-main') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="school-main"></div>');
    //  토스트를 가로채서 뭐라고 했는지 본다
    window.__toast = [];
    showUploadToast = (m) => window.__toast.push(String(m));
  }, [role, links || null]);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 칸이 사역자 교육 왼쪽에 있나 ───────────────────────────
console.log('\n① 운영관리 탭 차례');
{
  const pg = await setup(b, 'community_admin');
  const r = await pg.evaluate(() => {
    const ids = schoolVisibleTabs().map(x => x.id);
    const tab = SCHOOL_TABS.find(x => x.id === 'lecture');
    return { ids, i: ids.indexOf('lecture'), j: ids.indexOf('training'),
             label: tab && tab.label, section: tab && tab.section };
  });
  ok(r.i >= 0, '운영관리에 사용법 강의 칸이 있다', r.ids.join(','));
  ok(r.i === r.j - 1, '사역자 교육 바로 왼쪽이다', r.ids.join(','));
  ok(r.i === 0, '운영관리의 첫 칸이다', 'index=' + r.i);
  ok(r.section === 'ops', '학사가 아니라 운영 쪽에 붙었다', r.section);
  //  학사 화면에서는 안 보여야 한다 — 두 화면이 같은 틀을 쓴다
  const sch = await pg.evaluate(() => { schoolSection = 'school'; return schoolVisibleTabs().map(x => x.id); });
  ok(!sch.includes('lecture'), '학사관리 탭에는 안 섞인다', sch.join(','));
  await pg.close();
}

// ── ② 학생·학부모는 아예 못 본다 ─────────────────────────────
console.log('\n② 누가 보나');
{
  const pg = await setup(b, 'student');
  const r = await pg.evaluate(() => { schoolSection = 'ops'; return schoolVisibleTabs().map(x => x.id); });
  ok(r.length === 0, '학생에게는 운영관리 칸이 하나도 없다', r.join(','));
  await pg.close();
}
{
  const pg = await setup(b, 'teacher');
  const r = await pg.evaluate(() => schoolVisibleTabs().map(x => x.id));
  ok(r.includes('lecture'), '교사는 볼 수 있다 (강의는 교사가 보는 것)', r.join(','));
  ok(!r.includes('vehicle'), '그렇다고 행정 칸까지 열리지는 않는다', r.join(','));
  await pg.close();
}

// ── ③ 주소가 없으면 눌리지 않는다 ────────────────────────────
console.log('\n③ 주소가 하나도 없을 때');
{
  const pg = await setup(b, 'community_admin');
  const r = await pg.evaluate(async () => {
    await renderLectureHub();
    const el = document.getElementById('school-main');
    return {
      cards: el.querySelectorAll('[data-gl]').length,
      on:    el.querySelectorAll('button.glcard.on').length,
      txt:   el.innerText,
    };
  });
  ok(r.cards === 10, '열 강이 다 보인다 (주소가 없어도 차례는 보여야 한다)', r.cards);
  ok(r.on === 0, '누를 수 있는 카드가 하나도 없다', r.on);
  ok(/준비 중/.test(r.txt), '「준비 중」 이라고 말해 준다');
  ok(/승인해야 들어옵니다/.test(r.txt), '1강의 「꼭 기억할 한 가지」 가 보인다');
  ok(/매점 관리는 따로 열립니다/.test(r.txt), '9강의 한 가지도 보인다');
  //  총관리자가 아니면 넣으라고 하지 않는다 — 할 수 없는 일을 시키면 안 된다
  ok(!/주소 넣기/.test(r.txt), '관리자에게는 주소 넣기 단추가 없다');
  await pg.close();
}

// ── ④ 넣은 강만 열린다 ───────────────────────────────────────
console.log('\n④ 1강·5강만 넣었을 때');
{
  const pg = await setup(b, 'community_admin', { '1': U1, '5': U5, list: PLS });
  const r = await pg.evaluate(async () => {
    await renderLectureHub();
    const el = document.getElementById('school-main');
    const on = [...el.querySelectorAll('button.glcard.on')].map(x => x.dataset.gl);
    return { on, txt: el.innerText, html: el.innerHTML };
  });
  ok(r.on.join(',') === '1,5', '주소를 넣은 두 강만 눌린다', r.on.join(','));
  ok(/재생목록 열기/.test(r.txt), '재생목록 단추가 생긴다');
  ok(r.html.includes(PLS), '재생목록 단추가 그 주소를 가리킨다');
  ok(/10강 중 2강/.test(r.txt.replace(/\s+/g, ' ')) || /2.*10/.test(r.txt), '몇 강이 올라왔는지 알려 준다');

  //  열어 보기 — 임베드 주소에 그 강의 영상 id 가 들어가야 한다.
  //  (1강을 눌렀는데 5강이 나오면 못 알아챌 수 있어서 id 를 직접 잰다)
  const d = await pg.evaluate(() => {
    openLecture(5);
    const el = document.getElementById('school-main');
    const f = el.querySelector('iframe');
    return { src: f && f.getAttribute('src'), sel: guideSel, txt: el.innerText };
  });
  ok(d.sel === 5, '5강이 열렸다', d.sel);
  ok(/youtube-nocookie\.com\/embed\/bbbbbbbbbbb/.test(d.src || ''), '5강 영상 id 로 임베드한다', d.src);
  ok(/맡아 둔 돈과 쓰라고 준 돈은 다릅니다/.test(d.txt), '5강의 한 가지가 같이 보인다');
  ok(/4강/.test(d.txt) === false, '주소 없는 4강으로는 이어지지 않는다');

  //  주소 없는 강은 눌러도 안 열린다
  const bad = await pg.evaluate(() => {
    guideSel = null; renderLectureMain();
    window.__toast = [];
    openLecture(4);
    return { sel: guideSel, toast: window.__toast.join('|') };
  });
  ok(bad.sel === null, '주소 없는 강은 열리지 않는다', bad.sel);
  ok(/아직 주소가 없어요/.test(bad.toast), '왜 안 열리는지 말해 준다', bad.toast);
  await pg.close();
}

// ── ⑤ 주소 넣는 칸은 총관리자만 ──────────────────────────────
console.log('\n⑤ 주소 넣기');
{
  const pg = await setup(b, 'super_admin');
  const r = await pg.evaluate(async () => {
    await renderLectureHub();
    const el = document.getElementById('school-main');
    const before = /주소 넣기/.test(el.innerText);
    toggleGuideEdit();
    return { before, rows: el.querySelectorAll('input[id^="gl-in-"]').length, txt: el.innerText };
  });
  ok(r.before, '총관리자에게는 주소 넣기 단추가 보인다');
  ok(r.rows === 11, '열 강 + 재생목록 = 칸 열한 개', r.rows);
  ok(/모든 공동체/.test(r.txt), '모든 공동체가 함께 본다고 알려 준다');

  console.log('\n⑥ 저장하면 app_settings 에 JSON 으로');
  const s = await pg.evaluate(async () => {
    document.getElementById('gl-in-1').value = 'https://youtu.be/ccccccccccc';
    document.getElementById('gl-in-3').value = '   ';     // 빈 칸은 안 들어가야 한다
    document.getElementById('gl-in-list').value = 'https://youtube.com/playlist?list=PLzz';
    await saveGuideLinks();
    const row = (window.__ins.find(x => x.t === 'app_settings') || {}).rows;
    return { key: row && row[0] && row[0].key, val: row && row[0] && row[0].value,
             toast: window.__toast.join('|'), edit: guideEdit };
  });
  ok(s.key === 'guide_lecture_links', 'app_settings 의 한 칸에 담는다', s.key);
  const saved = JSON.parse(s.val || '{}');
  ok(saved['1'] === 'https://youtu.be/ccccccccccc', '1강 주소가 들어갔다', s.val);
  ok(!('3' in saved), '빈 칸은 넣지 않는다 (공백만 적은 것)', s.val);
  ok(saved.list === 'https://youtube.com/playlist?list=PLzz', '재생목록도 같이 담긴다', s.val);
  ok(/저장했어요/.test(s.toast), '저장했다고 알려 준다', s.toast);
  ok(s.edit === false, '저장하면 넣는 칸을 닫는다', s.edit);
  await pg.close();
}

// ── ⑦ 규칙에 막히면 거짓말하지 않는다 ────────────────────────
console.log('\n⑦ 0건으로 돌아왔을 때');
{
  const pg = await setup(b, 'super_admin');
  const r = await pg.evaluate(async () => {
    await renderLectureHub();
    toggleGuideEdit();
    document.getElementById('gl-in-1').value = 'https://youtu.be/ddddddddddd';
    //  RLS 에 막히면 에러 없이 **0건** 이 돌아온다. 그걸 성공으로 읽으면
    //  '저장했어요' 라고 해 놓고 아무것도 안 들어간 꼴이 된다.
    const real = sb.from;
    sb.from = (tbl) => tbl === 'app_settings'
      ? { upsert: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }
      : real(tbl);
    window.__toast = [];
    await saveGuideLinks();
    sb.from = real;
    return { toast: window.__toast.join('|'), links: JSON.stringify(guideLinks) };
  });
  ok(!/저장했어요/.test(r.toast), '저장했다고 하지 않는다', r.toast);
  ok(/권한이 없어요/.test(r.toast), '권한이 없다고 말해 준다', r.toast);
  ok(!/ddddddddddd/.test(r.links), '화면에도 넣은 척하지 않는다', r.links);
  await pg.close();
}

// ── ⑧ 총관리자가 아니면 저장 자체가 막힌다 ───────────────────
console.log('\n⑧ 관리자가 저장을 부르면');
{
  const pg = await setup(b, 'community_admin');
  const r = await pg.evaluate(async () => {
    await renderLectureHub();
    window.__toast = [];
    await saveGuideLinks();          // 단추가 없어도 함수는 부를 수 있다
    return { ins: window.__ins.filter(x => x.t === 'app_settings').length, toast: window.__toast.join('|') };
  });
  ok(r.ins === 0, '표에 아무것도 안 들어간다', r.ins);
  ok(/총관리자만/.test(r.toast), '총관리자만 할 수 있다고 말해 준다', r.toast);
  await pg.close();
}

// ── ⑨ 주소를 못 읽어도 목록은 보인다 ─────────────────────────
console.log('\n⑨ app_settings 를 못 읽을 때');
{
  const pg = await setup(b, 'community_admin');
  const r = await pg.evaluate(async () => {
    window.__err = { table: 'app_settings', e: { message: 'relation "app_settings" does not exist' } };
    await renderLectureHub();
    const el = document.getElementById('school-main');
    return { cards: el.querySelectorAll('[data-gl]').length, txt: el.innerText };
  });
  ok(r.cards === 10, '표가 없어도 열 강 목록은 그대로 보인다', r.cards);
  ok(!/불러오는 중/.test(r.txt), '「불러오는 중」 에서 멈추지 않는다');
  await pg.close();
}

await b.close();
done();
})();
