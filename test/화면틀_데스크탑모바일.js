//  🖥️📱 화면 틀 — 데스크탑·모바일 전수 점검
//
//    "아직 데스크탑에 최적화 되지 않아 보이는 페이지가 많아 ...
//     같은 파트인데 위치가 다르고 ... 전수조사해서 ...
//     데스크탑은 좌우 여백 이렇게 두지말고 전체화면을 잘 사용해서"
//
//  재 보니 화면 틀이 **세 개**였습니다 —
//    .page(1180 가운데) · .spage(1200, 왼쪽으로만 밀림) · 쪽마다 붙인
//    max-width 720~1200px. 게다가 #school-main 처럼 !important 로
//    여백을 따로 덮어쓴 자리도 있었습니다. 그래서 메뉴를 누를 때마다
//    내용 시작 자리가 옮겨 다니고 오른쪽은 늘 비어 있었습니다.
//
//  한 틀로 묶었습니다. **그 상태를 숫자로 못 박습니다.**
const { launch, openApp, ok, done } = require('./_harness');

//  재는 법 — 지금 보이는 스크롤 칸과 그 안의 틀 상자
const MEASURE = `async (mode) => {
  try { setMode(mode); } catch (e) { return null; }
  await new Promise(r => setTimeout(r, 140));
  const doc = document.documentElement;
  const sp = [...document.querySelectorAll('.scroll-page')].find(x => x.offsetParent !== null);
  if (!sp) return { skip: true };
  const box = sp.querySelector('.pg, .page, .spage, .pg-narrow');
  const b = box && box.getBoundingClientRect();
  return {
    over: doc.scrollWidth - innerWidth,
    pad: getComputedStyle(sp).paddingLeft,
    left: b ? Math.round(b.left) : null,
    w: b ? Math.round(b.width) : null,
    narrow: box ? box.classList.contains('pg-narrow') : false,
  };
}`;

async function sweep(b, vp) {
  const pg = await openApp(b, { viewport: vp });
  const modes = await pg.evaluate(() => {
    const set = new Set();
    document.querySelectorAll('[onclick*="setMode("]').forEach(el => {
      const m = /setMode\('([a-zA-Z0-9_-]+)'/.exec(el.getAttribute('onclick') || '');
      if (m) set.add(m[1]);
    });
    return [...set];
  });
  const out = {};
  for (const m of modes) {
    try { out[m] = await pg.evaluate(eval(MEASURE), m); } catch (_) { out[m] = null; }
  }
  await pg.close();
  return out;
}

(async () => {
const b = await launch();

// ── ① 데스크탑 ───────────────────────────────────────────────
console.log('\n① 데스크탑 1920');
{
  const r = await sweep(b, { width:1920, height:1000 });
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.left !== null);
  console.log('       잰 화면:', seen.length + '개');

  ok(seen.length >= 8, '틀을 쓰는 화면을 여러 개 쟀다 (' + seen.length + '개)');

  const lefts = [...new Set(seen.filter(([,v]) => !v.narrow).map(([, v]) => v.left))];
  console.log('       왼쪽 끝:', JSON.stringify(lefts));
  ok(lefts.length === 1,
     '모든 화면의 내용이 **같은 자리**에서 시작한다 ← 메뉴마다 옮겨 다니던 것');

  const widths = [...new Set(seen.filter(([,v]) => !v.narrow).map(([, v]) => v.w))];
  console.log('       틀 너비:', JSON.stringify(widths));
  ok(widths.length === 1, '너비도 모두 같다');
  ok(widths[0] >= 1500,
     '넓은 화면에서 ' + widths[0] + 'px 를 쓴다 ← 예전 820~1200px 가운데 단이 아니다');

  const over = seen.filter(([, v]) => v.over > 1);
  ok(over.length === 0, '가로로 넘치는 화면이 없다' + (over.length ? ' (' + over.map(x=>x[0]).join(',') + ')' : ''));
}

// ── ② 노트북 ─────────────────────────────────────────────────
console.log('\n② 노트북 1440');
{
  const r = await sweep(b, { width:1440, height:900 });
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.left !== null && !v.narrow);
  const lefts = [...new Set(seen.map(([, v]) => v.left))];
  const widths = [...new Set(seen.map(([, v]) => v.w))];
  console.log('       왼쪽 끝:', JSON.stringify(lefts), '· 너비:', JSON.stringify(widths));
  ok(lefts.length === 1, '여기서도 모두 같은 자리에서 시작한다');
  ok(widths.length === 1 && widths[0] > 1200,
     '화면이 좁아지면 틀도 같이 좁아진다 (' + widths[0] + 'px)');
  ok(Object.values(r).every(v => !v || v.skip || v.over <= 1), '가로 넘침 없음');
}

// ── ③ 아이폰 ─────────────────────────────────────────────────
console.log('\n③ 아이폰 390');
{
  const r = await sweep(b, { width:390, height:844 });
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.left !== null);
  const lefts = [...new Set(seen.map(([, v]) => v.left))];
  const pads  = [...new Set(seen.map(([, v]) => v.pad))];
  console.log('       왼쪽 끝:', JSON.stringify(lefts), '· 여백:', JSON.stringify(pads));
  ok(lefts.length === 1, '휴대폰에서도 모두 같은 자리에서 시작한다');
  ok(pads.length === 1,
     '여백이 한 가지다 ← #school-main 만 !important 로 2px 달랐다');
  ok(parseFloat(pads[0]) <= 20, '휴대폰 여백이 ' + pads[0] + ' 로 좁다 (화면을 넓게 쓴다)');

  const over = Object.entries(r).filter(([, v]) => v && !v.skip && v.over > 1);
  ok(over.length === 0,
     '휴대폰에서 가로로 넘치는 화면이 없다' + (over.length ? ' (' + over.map(x=>x[0]).join(',') + ')' : ''));
}

// ── ④ 아주 좁은 휴대폰 ───────────────────────────────────────
console.log('\n④ 좁은 휴대폰 360');
{
  const r = await sweep(b, { width:360, height:740 });
  const over = Object.entries(r).filter(([, v]) => v && !v.skip && v.over > 1);
  ok(over.length === 0,
     '360px 에서도 가로로 넘치지 않는다' + (over.length ? ' (' + over.map(x=>x[0]).join(',') + ')' : ''));
}

// ── ⑤ 왼쪽 명단이 본문을 먹지 않는다 ─────────────────────────
console.log('\n⑤ 왼쪽 명단이 있는 화면 (TCS기록·독서)');
{
  for (const [vp, label, want] of [
    [{ width:1920, height:1000 }, '데스크탑', 'side'],
    [{ width:390,  height:844  }, '아이폰',   'stack'],
  ]) {
    const pg = await openApp(b, { viewport: vp });
    const r = await pg.evaluate(async () => {
      setMode('tcs');
      await new Promise(r2 => setTimeout(r2, 160));
      const panel = document.getElementById('tcs-student-panel');
      const main  = document.getElementById('tcs-main');
      return {
        panel: Math.round(panel.getBoundingClientRect().width),
        main:  Math.round(main.getBoundingClientRect().width),
        dir: getComputedStyle(panel.parentElement).flexDirection,
      };
    });
    await pg.close();
    console.log(`       ${label}: 명단 ${r.panel} · 본문 ${r.main} (${r.dir})`);
    if (want === 'side') {
      ok(r.dir === 'row' && r.panel > 150 && r.main > 1000,
         '데스크탑에서는 명단이 옆에 있고 본문이 넓다');
    } else {
      ok(r.dir === 'column', '휴대폰에서는 명단이 위로 눕는다');
      ok(r.main >= 380,
         '본문이 화면 폭을 다 쓴다 (' + r.main + 'px) ← 예전엔 170px 밖에 안 됐다');
    }
  }
}

await b.close();
done();
})();
