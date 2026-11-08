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
  const sb = sp.getBoundingClientRect();
  const pad = parseFloat(getComputedStyle(sp).paddingLeft);
  //  ⚠️ 왼쪽 끝을 '화면 기준' 으로 견주면 안 된다. 기도·채팅은 옆에 패널이
  //     있어서 담는 칸 자체가 오른쪽에서 시작한다 (어긋난 게 아니다).
  //     담는 칸 안에서 **얼마나 떨어져 있는지** 를 본다.
  return {
    over: doc.scrollWidth - innerWidth,
    pad,
    inset: b ? Math.round(b.left - sb.left - pad) : null,  // 여백 빼고 더 띄운 만큼
    w: b ? Math.round(b.width) : null,
    room: Math.round(sb.width - pad * 2),             // 쓸 수 있는 폭
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
  //  틀 상자를 쓰는 화면만 본다. 홈·TCS기록·내아이·독서는 자기 배치를
  //  쓰고(위젯 격자·좌우 분할) 틀 상자가 없다 — 가로 넘침만 따로 본다.
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.inset !== null);
  console.log('       잰 화면:', seen.length + '개');

  ok(seen.length >= 8, '틀을 쓰는 화면을 여러 개 쟀다 (' + seen.length + '개)');

  const wide = seen.filter(([, v]) => !v.narrow);

  //  틀이 1600 에서 멈추면 남는 자리는 **좌우로 똑같이** 나눠야 한다.
  //  예전 .spage 는 왼쪽으로만 밀어서 오른쪽이 늘 비어 있었다.
  const offCenter = wide.filter(([, v]) => Math.abs(v.inset - (v.room - v.w) / 2) > 1);
  console.log('       띄운 만큼 / 가운데여야 할 값:',
    JSON.stringify(wide.map(([k, v]) => k + ':' + v.inset + '/' + Math.round((v.room - v.w) / 2))));
  ok(offCenter.length === 0,
     '남는 자리를 좌우로 똑같이 나눈다 ← 예전엔 왼쪽으로만 밀려 오른쪽이 비었다'
     + (offCenter.length ? ' — 어긋난 곳: ' + offCenter.map(x => x[0]).join(',') : ''));

  //  쓸 수 있는 폭을 다 쓰되 1600 에서 멈춘다
  const bad = wide.filter(([, v]) => v.w !== Math.min(1600, v.room));
  console.log('       틀 너비:', JSON.stringify(wide.map(([k, v]) => k + ':' + v.w + '/' + v.room)));
  ok(bad.length === 0,
     '모든 화면이 쓸 수 있는 폭을 다 쓴다 (1600 에서 멈춤)'
     + (bad.length ? ' — 어긋난 곳: ' + bad.map(x => x[0]).join(',') : ''));
  const widest = Math.max(...wide.map(([, v]) => v.w));
  ok(widest >= 1400,
     '제일 넓은 화면이 ' + widest + 'px 를 쓴다 ← 예전 820~1200px 가운데 단이 아니다');

  const over = Object.entries(r).filter(([, v]) => v && !v.skip && v.over > 1);
  ok(over.length === 0, '틀이 없는 화면까지 통틀어 가로로 넘치는 곳이 없다' + (over.length ? ' (' + over.map(x=>x[0]).join(',') + ')' : ''));
}

// ── ② 노트북 ─────────────────────────────────────────────────
console.log('\n② 노트북 1440');
{
  const r = await sweep(b, { width:1440, height:900 });
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.inset !== null && !v.narrow);
  const insets = [...new Set(seen.map(([, v]) => v.inset))];
  const bad = seen.filter(([, v]) => v.w !== Math.min(1600, v.room));
  console.log('       띄운 만큼:', JSON.stringify(insets),
              '· 너비:', JSON.stringify(seen.map(([k, v]) => k + ':' + v.w)));
  ok(seen.every(([, v]) => Math.abs(v.inset - (v.room - v.w) / 2) <= 1),
     '여기서도 남는 자리를 좌우로 똑같이 나눈다');
  ok(bad.length === 0, '화면이 좁아지면 틀도 같이 좁아진다');
  ok(Object.values(r).every(v => !v || v.skip || v.over <= 1), '가로 넘침 없음');
}

// ── ③ 아이폰 ─────────────────────────────────────────────────
console.log('\n③ 아이폰 390');
{
  const r = await sweep(b, { width:390, height:844 });
  const seen = Object.entries(r).filter(([, v]) => v && !v.skip && v.inset !== null);
  const insets = [...new Set(seen.map(([, v]) => v.inset))];
  const pads  = [...new Set(seen.map(([, v]) => v.pad))];
  console.log('       띄운 만큼:', JSON.stringify(insets), '· 여백:', JSON.stringify(pads));
  ok(insets.length === 1 && insets[0] === 0,
     '휴대폰에서는 틀이 폭을 다 써서 모두 같은 자리에서 시작한다');
  ok(pads.length === 1,
     '여백이 한 가지다 ← #school-main 만 !important 로 2px 달랐다');
  ok(pads[0] <= 20, '휴대폰 여백이 ' + pads[0] + 'px 로 좁다 (화면을 넓게 쓴다)');

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

// ── ⑥ 홈·채팅·일정·기도·노트 (틀 상자가 없는 다섯 화면) ──────
console.log('\n⑥ 홈·채팅·일정·기도·노트');
{
  const VIEWS = { home:'home-view', chat:'chat-view', calendar:'calendar-view',
                  prayer:'prayer-view', note:'note-view' };
  for (const [vp, label] of [[{ width:1920, height:1000 }, '데스크탑'],
                             [{ width:390,  height:844  }, '아이폰']]) {
    const pg = await openApp(b, { viewport: vp });
    const r = await pg.evaluate(async (views) => {
      const out = {};
      for (const [m, vid] of Object.entries(views)) {
        try { setMode(m); } catch (e) { out[m] = { err:1 }; continue; }
        await new Promise(r2 => setTimeout(r2, 200));
        const view = document.getElementById(vid);
        if (!view || view.offsetParent === null) { out[m] = { hidden:1 }; continue; }
        const vb = view.getBoundingClientRect();
        //  뷰 밖으로 삐져나온 것이 있나
        let worst = 0;
        view.querySelectorAll('*').forEach(el => {
          if (el.offsetParent === null) return;
          const b2 = el.getBoundingClientRect();
          if (b2.width === 0) return;
          const o = Math.round(b2.right - vb.right);
          if (o > worst) worst = o;
        });
        out[m] = { w: Math.round(vb.width), worst,
                   over: document.documentElement.scrollWidth - innerWidth };
      }
      return out;
    }, VIEWS);

    const shown = Object.entries(r).filter(([, v]) => v && !v.err && !v.hidden);
    console.log(`       ${label}: ` + shown.map(([k, v]) => `${k} ${v.w}`).join(' · '));
    ok(shown.length === 5, label + ' — 다섯 화면이 모두 뜬다 (' + shown.length + '개)');
    const bad = shown.filter(([, v]) => v.worst > 2);
    ok(bad.length === 0,
       label + ' — 화면 밖으로 삐져나온 것이 없다' + (bad.length ? ' (' + bad.map(x=>x[0]).join(',') + ')' : ''));
    const ov = shown.filter(([, v]) => v.over > 1);
    ok(ov.length === 0, label + ' — 가로 스크롤이 생기지 않는다');
    await pg.close();
  }
}

// ── ⑦ 글이 긴 카드는 넓은 화면에서 나란히 놓인다 ─────────────
console.log('\n⑦ 기도 카드 — 글줄이 너무 길어지지 않게');
{
  for (const [vp, label, wantCols] of [
    [{ width:1920, height:1000 }, '데스크탑', 3],
    [{ width:1440, height:900  }, '노트북',   2],
    [{ width:390,  height:844  }, '아이폰',   1],
  ]) {
    const pg = await openApp(b, { viewport: vp });
    const r = await pg.evaluate(async () => {
      window.__DB.prayers = [1,2,3,4].map(i => ({
        id:'p'+i, community_id:'c1', member_id:'me', member_name:'김선생',
        scope:'전체', title:'제목'+i, body:'기도 제목이 길게 적힌 경우입니다. '.repeat(6),
        created_at:'2026-01-0'+i+'T00:00:00Z' }));
      setMode('prayer');
      try { await renderPrayers(); } catch (e) { try { paintPrayers(); } catch (e2) {} }
      await new Promise(r2 => setTimeout(r2, 350));
      const g = document.querySelector('.pray-grid');
      const c = document.querySelector('.prayer-card');
      return {
        cols: g ? getComputedStyle(g).gridTemplateColumns.split(' ').length : null,
        card: c ? Math.round(c.getBoundingClientRect().width) : null,
        n: document.querySelectorAll('.prayer-card').length,
      };
    });
    await pg.close();
    console.log(`       ${label}: ${r.cols}칸 · 카드 ${r.card}px · ${r.n}장`);
    ok(r.cols === wantCols, `${label} 에서 ${wantCols}칸으로 놓인다`);
    ok(r.n === 4, '카드가 다 나온다');
    if (vp.width > 1000) {
      ok(r.card <= 560,
         `카드가 ${r.card}px — 글줄이 읽을 만하다 ← 예전엔 1492px 한 장이었다`);
    } else {
      ok(r.card >= 340, `휴대폰에서는 카드가 폭을 다 쓴다 (${r.card}px)`);
    }
  }
}

await b.close();
done();
})();
