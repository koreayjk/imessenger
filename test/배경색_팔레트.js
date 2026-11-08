//  🎨 배경색 팔레트 — 원하는 색을 직접 (개선창 · 김가은)
//
//    "배경색에 팔레트를 만들어서 자신이 원하는 색깔을 할수있게하면
//     색깔이 다양해질것 같네요!!"
//
//  저장은 원래 아무 색이나 됐습니다 — 고르는 자리가 12개로 막혀 있었습니다.
//  ⚠️ 색 글자를 그대로 믿으면 안 됩니다. 엉뚱한 글자가 들어가면 그 사람
//     얼굴 자리가 **모든 화면에서** 깨집니다.
const { launch, openApp, ok, done } = require('./_harness');

(async () => {
const b = await launch();

// ── ① 색 글자 가려내기 ──────────────────────────────────────
console.log('\n① 색 글자 가려내기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(() => ({
    ok6: avHexOk('#1d3a5f'), okUp: avHexOk('#1D3A5F'),
    short: avHexOk('#abc'), noHash: avHexOk('1d3a5f'),
    word: avHexOk('red'), empty: avHexOk(''), nil: avHexOk(null),
    evil: avHexOk('#000;background:url(x)'),
    same: avSameColor('#1D3A5F', '#1d3a5f'),
    diff: avSameColor('#1d3a5f', '#2a5298'),
    custom: avCustomColor('#ff00aa'), listed: avCustomColor('#1d3a5f'),
    junkCustom: avCustomColor('red'),
    hexOf: avHexOf('#ff00aa'), hexOfBad: avHexOf('red'),
  }));
  await pg.close();
  ok(r.ok6 && r.okUp, '#rrggbb 는 대소문자 모두 받는다');
  ok(!r.short && !r.noHash && !r.word && !r.empty && !r.nil,
     '#abc · 샵없음 · 영어이름 · 빈값 은 안 받는다');
  ok(!r.evil, "'#000;background:url(x)' 같은 글자를 막는다 ← 화면이 깨진다");
  ok(r.same && !r.diff, '대소문자를 무시하고 견준다');
  ok(r.custom && !r.listed && !r.junkCustom, '열두 색에 없는 제대로 된 색만 직접 고른 색으로 본다');
  ok(r.hexOf === '#ff00aa' && r.hexOfBad === '#1d3a5f', '고르개 값은 늘 제대로 된 색이다');
}

// ── ② 화면에 팔레트가 있나 ──────────────────────────────────
console.log('\n② 팔레트');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.color = '#1d3a5f'; ME.initials = '김';
    document.getElementById('profile-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="profile-content"></div>');
    await renderProfilePage();
    _avOpen = false; toggleAvatarPicker();
    const el = document.body;
    const lab = el.querySelector('[data-avc-pick]');
    return {
      swatches: el.querySelectorAll('[data-avc]').length,
      pick: !!lab,
      input: !!el.querySelector('#av-color-pick'),
      inputType: (el.querySelector('#av-color-pick')||{}).type,
      emoji: lab ? lab.innerText.includes('🎨') : false,
      //  ⚠️ innerText 는 '보이는' 글자만 준다. 이 시험은 화면을 띄우지
      //     않고 그리기만 해서 늘 빈 글자가 나왔다 — textContent 로 본다.
      hint: el.textContent.includes('직접 고를 수 있어요'),
    };
  });
  await pg.close();
  ok(r.swatches === 12, '기본 열두 색은 그대로 있다');
  ok(r.pick && r.input && r.inputType === 'color',
     '🎨 색 고르개가 생겼다 ← 이게 요청이었다');
  ok(r.emoji, '아직 기본 색이면 🎨 표가 보인다');
  ok(r.hint, '어떻게 쓰는지 한 줄 적어준다');
}

// ── ③ 직접 고른 색 저장 ─────────────────────────────────────
console.log('\n③ 저장');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.color = '#1d3a5f'; ME.initials = '김';
    document.getElementById('profile-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="profile-content"></div>');
    await renderProfilePage();
    _avOpen = false; toggleAvatarPicker();
    const out = {};
    window.__upd = [];
    await saveMyAvatarColor('#FF00AA');
    out.sent = JSON.stringify(window.__upd);
    out.me = ME.color;
    const lab = document.querySelector('[data-avc-pick]');
    out.labBg = lab ? lab.style.background : '';
    out.labBorder = lab ? lab.style.borderColor : '';
    out.emojiGone = lab ? !lab.innerText.includes('🎨') : false;
    //  엉뚱한 글자는 막는다
    let said = '';
    const real = window.showUploadToast; window.showUploadToast = m => { said += m; };
    window.__upd = [];
    await saveMyAvatarColor('red; background:url(x)');
    window.showUploadToast = real;
    out.badSent = JSON.stringify(window.__upd);
    out.badSaid = said;
    out.stillMe = ME.color;
    return out;
  });
  await pg.close();
  ok(/"color":"#ff00aa"/.test(r.sent), '고른 색을 소문자로 저장한다');
  ok(r.me === '#ff00aa', '내 색이 바뀐다');
  ok(/255, 0, 170|#ff00aa/.test(r.labBg), '🎨 자리가 그 색으로 칠해진다');
  ok(r.emojiGone, '직접 고른 색이면 🎨 글자가 빠진다 (색이 보여야 하니까)');
  ok(r.badSent === '[]', '엉뚱한 글자는 보내지도 않는다');
  ok(/알아보지 못했어요/.test(r.badSaid), '왜 안 되는지 알려준다');
  ok(r.stillMe === '#ff00aa', '막힌 뒤에도 원래 색이 그대로 남는다');
}

// ── ④ 미리보기는 저장하지 않는다 ────────────────────────────
console.log('\n④ 미리보기');
{
  const pg = await openApp(b, { as:'teacher' });
  const r = await pg.evaluate(async () => {
    ME.color = '#1d3a5f'; ME.initials = '김';
    document.getElementById('profile-content') ||
      document.body.insertAdjacentHTML('beforeend', '<div id="profile-content"></div>');
    await renderProfilePage();
    _avOpen = false; toggleAvatarPicker();
    window.__upd = [];
    previewMyAvatarColor('#00ccff');
    previewMyAvatarColor('#00ddff');
    const pv = document.getElementById('av-preview');
    return { sent: JSON.stringify(window.__upd), me: ME.color,
             pv: pv ? pv.style.background : '' };
  });
  await pg.close();
  ok(r.sent === '[]',
     '색을 끌어 고르는 동안에는 서버에 보내지 않는다 ← 한 번 끌 때마다 저장하면 안 된다');
  ok(r.me === '#1d3a5f', '아직 내 색은 그대로다');
  ok(/0, 221, 255|#00ddff/.test(r.pv), '미리보기만 바뀐다');
}

await b.close();
done();
})();
