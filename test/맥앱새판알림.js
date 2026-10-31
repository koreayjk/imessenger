//  🖥 옛 맥 앱을 쓰는 분에게 새 판이 나왔다고 알리는가
//
//  맥 앱은 스스로 업데이트하지 않습니다. 1.0.0 은 마이크를 쓸 자격이 없어서,
//  맥이 거절 대신 **조용한 마이크**를 내줍니다 — 쓰는 분은 전화가 멀쩡한 줄
//  알고 상대에게만 목소리가 안 갑니다. 그러니 '알려주면 좋은 것' 이 아니라
//  '알려줘야만 하는 것' 입니다. 알림이 조용히 사라지지 않게 못 박아 둡니다.
const { launch, openApp, ok, done } = require('./_harness.js');

const UA = (v) => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
                + '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
                + (v ? ' TCSDesktop/' + v : '');

const bar = (pg) => pg.evaluate(() => {
  const b = document.getElementById('dt-bar');
  return b ? b.textContent.replace(/\s+/g, ' ').trim() : null;
});

(async () => {
  const b = await launch();

  // ── ① 옛 판 — 알려야 한다 ──────────────────────────────────────
  {
    const pg = await openApp(b, { ua: UA('1.0.0') });
    ok(await pg.evaluate(() => desktopVer()) === '1.0.0', '맥 앱 판 번호를 알아본다');
    ok(await pg.evaluate(() => desktopOld()) === true, '옛 판이라고 가린다');

    await pg.evaluate(() => callInit());        // 전화 준비가 될 때 알린다
    const txt = await bar(pg);
    console.log('     띠:', txt);
    ok(!!txt && /맥 앱이 옛 판이에요 \(1\.0\.0\)/.test(txt), '옛 판이라고 적는다');
    ok(!!txt && /새 판 1\.1\.0/.test(txt), '받아야 할 판 번호를 적는다');
    ok(!!txt && /목소리가 상대에게 가지 않던/.test(txt), '무엇이 고쳐졌는지 적는다');

    //  '오늘은 그만' 을 누르면 접히고, 바로 다시 뜨지는 않는다
    await pg.click('#dt-bar button');
    ok(await bar(pg) === null, '오늘은 그만 을 누르면 접힌다');
    await pg.evaluate(() => showDesktopUpdateBar());
    ok(await bar(pg) === null, '접은 뒤에는 바로 다시 뜨지 않는다');
    //  ...하지만 하루가 지나면 다시 뜬다. 영영 숨기면 전화가 안 되는 채로 지냅니다.
    await pg.evaluate(() => { localStorage.setItem('tcs-dtbar', String(Date.now() - 1)); showDesktopUpdateBar(); });
    ok((await bar(pg)) !== null, '하루 지나면 다시 알려 준다');
    await pg.close();
  }

  // ── ② 새 판 · 보통 브라우저 — 가만히 있어야 한다 ───────────────
  {
    const pg = await openApp(b, { ua: UA('1.1.0') });
    await pg.evaluate(() => callInit());
    ok(await pg.evaluate(() => desktopOld()) === false, '새 판은 옛 판이 아니다');
    ok(await bar(pg) === null, '새 판에는 아무것도 안 띄운다');
    await pg.close();
  }
  {
    const pg = await openApp(b, { ua: UA('') });
    await pg.evaluate(() => callInit());
    ok(await pg.evaluate(() => desktopVer()) === '', '맥 앱이 아니면 판 번호가 없다');
    ok(await bar(pg) === null, '보통 브라우저에는 아무것도 안 띄운다');
    await pg.close();
  }

  // ── ③ 판 번호 견주기 — 글자로 보면 거꾸로 나온다 ────────────────
  {
    const pg = await openApp(b, { ua: UA('1.0.0') });
    const v = await pg.evaluate(() => ({
      a: verOlder('1.9.0', '1.10.0'),      // 글자로 보면 '1.9' > '1.10' 이다
      b: verOlder('1.10.0', '1.9.0'),
      c: verOlder('1.0.0', '1.0.0'),
      d: verOlder('1.0', '1.0.1'),
      e: verOlder('2.0.0', '1.9.9'),
    }));
    ok(v.a === true && v.b === false, '1.9 가 1.10 보다 앞이다 (글자로 견주지 않는다)');
    ok(v.c === false, '같은 판은 옛 판이 아니다');
    ok(v.d === true, '마디 수가 달라도 바르게 견준다');
    ok(v.e === false, '2.0 이 1.9 보다 뒤다');
    await pg.close();
  }

  // ── ④ 전화가 안 될 때도 까닭에 적는다 ───────────────────────────
  //  옛 판은 설정을 아무리 고쳐도 안 됩니다. '설정에서 켜세요' 만
  //  적으면 그 분은 설정만 들여다보다 끝납니다.
  {
    const pg = await openApp(b, { ua: UA('1.0.0') });
    const w = await pg.evaluate(() => {
      CALL = { status: 'accepted', linked: true, startedAt: Date.now() - 20000, sigIn: 3,
               hasTurn: true, playing: true, rlvMax: 0.3, micMax: 0.3,
               aud: { inb: 900, out: 900, mic: 0.3, rlv: 0.3 },
               micTrack: { label: 'x', live: true, muted: true } };
      return callQuietWhy();
    });
    console.log('     까닭:', w);
    ok(/맥 앱이 옛 판\(1\.0\.0\)이라 마이크를 못 씁니다/.test(w || ''), '옛 맥 앱이면 그것부터 말한다');
    ok(/새 판 1\.1\.0 을 받아/.test(w || ''), '어떻게 고치는지 적는다');
    ok(/설정을 고쳐도 이 판으로는 안 됩니다/.test(w || ''), '설정만 들여다보지 않게 못 박는다');

    const w2 = await pg.evaluate(() => { CALL.micTrack = { label: 'x', live: true, muted: false }; return callQuietWhy(); });
    ok(w2 === '', '마이크가 멀쩡하면 옛 판이어도 통화 중에 떠들지 않는다');
    await pg.close();
  }

  await b.close();
  done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
