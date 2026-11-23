//  🙏 기도제목 — 쓴 글이 그대로 글자로 보이게
//
//  개선창 · 김연정 (프로토스, 11/16):
//    「수정 가능하도록 / 엔터키를 통해 줄바꾸기가 가능하도록
//      (현재 줄바꾸기를 해서 올려도 줄바꾸기가 되지 않습니다)」
//
//  줄바꿈이 사라지던 까닭은 **글을 HTML 로 꽂고 있었기 때문** 입니다.
//  HTML 은 줄바꿈 글자를 빈칸 하나로 봅니다. 그리고 같은 이유로,
//  아이가 쓴 제목·본문에 들어간 태그가 **그대로 실행되고 있었습니다.**
//  선생님·관리자도 같은 화면을 보므로 남의 화면에서 도는 글이 됩니다.
//  (바로 옆 댓글 칸은 이미 escHtml + pre-wrap 으로 제대로 하고 있었습니다.
//   글 본문만 빠져 있었습니다.)
//
//  재는 것:
//   ① 태그를 쓴 글이 **글자 그대로** 보이나 (실행되지 않나)
//   ② 엔터로 나눈 줄이 줄로 보이나
//   ③ 왼쪽 목록(패널)에서도 마찬가지인가
//   ④ 올린이 이름도 거르나
const { launch, openApp, ok, done } = require('./_harness');

const EVIL = '<img src=x onerror="window.__pwned=1">';
const NAME = '<b>홍길동</b>';
const BODY = '첫 줄입니다.\n둘째 줄입니다.\n\n넷째 줄입니다.';

async function setup(b) {
  const pg = await openApp(b, { as: 'teacher' });
  await pg.evaluate(([evil, name, body]) => {
    window.__pwned = 0;
    prayers = [{
      id: 'pr1', title: '기도제목 ' + evil, body: body + evil,
      member_id: 'other', member_name: name, scope: '전체',
      prayer_count: 2, created_at: '2026-11-16T00:00:00Z',
    }];
    prayerJoined = {}; prayerCmts = {}; prayerCmtOpen = {};
    ['prayer-list','panel-body'].forEach(id => {
      document.getElementById(id) ||
        document.body.insertAdjacentHTML('beforeend', `<div id="${id}"></div>`);
    });
  }, [EVIL, NAME, BODY]);
  return pg;
}

(async () => {
const b = await launch();

// ── ① 글이 실행되지 않고 글자로 보이나 ──────────────────────
console.log('\n① 태그를 쓴 글');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    renderPrayerContent();
    await new Promise(r => setTimeout(r, 250));   // onerror 가 돌 틈을 준다
    const el = document.getElementById('prayer-list');
    //  올린이 이름이 들어가는 칸 (아바타 다음, 분류·날짜 윗줄)
    const nameEl = el.querySelector('.prayer-card div[style*="font-size:13.5px"]');
    return {
      pwned: window.__pwned,
      imgs: el.querySelectorAll('img').length,
      nameTags: nameEl ? nameEl.querySelectorAll('*').length : -1,
      nameText: nameEl ? nameEl.textContent : '(칸을 못 찾음)',
      text: el.textContent,
      html: el.innerHTML,
    };
  });
  ok(r.pwned === 0, '글에 적힌 코드가 돌지 않는다', 'pwned=' + r.pwned);
  ok(r.imgs === 0, '글에 적힌 <img> 가 그림으로 들어가지 않는다', r.imgs);
  ok(/<img src=x onerror=/.test(r.text), '대신 글자 그대로 보인다');
  ok(/&lt;img src=x onerror=/.test(r.html), '화면 소스에는 거른 꼴로만 들어간다');
  //  ⚠️ 카드 안의 <b> 를 세면 안 됩니다 — 「2명」 을 굵게 쓰는 <b> 가 원래 있습니다.
  //     올린이 이름 **자리** 에 태그가 생겼는지를 봅니다.
  ok(r.nameTags === 0, '올린이 이름의 태그가 태그로 안 산다', r.nameTags);
  ok(/<b>홍길동<\/b>/.test(r.nameText), '이름이 적은 그대로 보인다', r.nameText);
  await pg.close();
}

// ── ② 엔터로 나눈 줄이 줄로 보이나 ──────────────────────────
console.log('\n② 줄바꿈');
{
  const pg = await setup(b);
  //  ⚠️ 시험 화면에서는 카드가 실제로 그려지지 않아 높이가 0 입니다.
  //     눈에 보이는 높이로 재면 못 잽니다 — 줄을 나누는 <br> 가 들어갔는지를 봅니다.
  //     (escHtml() 이 \n 을 <br> 로 바꿉니다. 전에는 글을 HTML 로 꽂아서
  //      줄바꿈 글자가 빈칸으로 삼켜졌습니다.)
  const r = await pg.evaluate(() => {
    renderPrayerContent();
    const p = document.querySelector('#prayer-list .prayer-card p');
    return { brs: p.querySelectorAll('br').length, html: p.innerHTML.slice(0, 120) };
  });
  ok(r.brs === 3, '엔터 세 번이 줄바꿈 셋으로 들어간다 (네 줄)', r.brs + '개 · ' + r.html);
  await pg.close();
}

// ── ③ 왼쪽 목록에서도 ───────────────────────────────────────
console.log('\n③ 왼쪽 목록');
{
  const pg = await setup(b);
  const r = await pg.evaluate(async () => {
    renderPrayerPanel();
    await new Promise(r => setTimeout(r, 250));
    const el = document.getElementById('panel-body');
    return { pwned: window.__pwned, imgs: el.querySelectorAll("img").length, text: el.textContent };
  });
  ok(r.pwned === 0, '목록에서도 코드가 돌지 않는다', 'pwned=' + r.pwned);
  ok(r.imgs === 0, '목록에도 <img> 가 안 생긴다', r.imgs);
  ok(/기도제목 <img/.test(r.text), '제목이 글자 그대로 보인다');
  await pg.close();
}

await b.close();
done();
})();
