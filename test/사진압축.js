//  📸 사진 올리기 — 줄여서, jpg 로
//
//  아이폰은 기본으로 HEIC 로 찍습니다. 사파리는 그대로 읽지만 크롬·엣지·
//  파이어폭스는 못 읽습니다. 그러면 줄이기가 조용히 실패하고 **원본이
//  그대로 올라갔습니다** — 압축도 안 되고, 올린 사람 말고는 아무도 못 보는
//  파일이 자리만 차지했습니다.
const { launch, openApp, ok, done } = require('./_harness.js');

//  진짜 사진을 하나 만든다 (캔버스로 그려서 File 로)
const MAKE = `(async (w, h, name, type) => {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const x = c.getContext('2d');
  //  단색이면 jpeg 가 너무 작아져서 '줄였다' 를 못 잰다. 잡스럽게 그린다.
  const im = x.createImageData(w, h);
  for (let i = 0; i < im.data.length; i += 4) {
    im.data[i] = (i * 7) % 255; im.data[i+1] = (i * 13) % 255;
    im.data[i+2] = (i * 29) % 255; im.data[i+3] = 255;
  }
  x.putImageData(im, 0, 0);
  const blob = await new Promise(r => c.toBlob(r, 'image/jpeg', 1));
  return new File([blob], name, { type: type || 'image/jpeg' });
})`;

(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'student' });

  // ── 큰 사진은 줄인다 ────────────────────────────────────────────
  const big = await pg.evaluate(async (mk) => {
    const f = await eval(mk)(3000, 2000, '큰사진.jpg');
    const s = await shrinkImage(f, { maxDim: 1600, quality: 0.82 });
    const dim = await new Promise(res => {
      const im = new Image(); im.onload = () => res({ w: im.naturalWidth, h: im.naturalHeight });
      im.src = URL.createObjectURL(s);
    });
    return { was: f.size, now: s.size, name: s.name, type: s.type, ...dim };
  }, MAKE);
  console.log('     큰 사진:', JSON.stringify(big));
  ok(big.now < big.was, '큰 사진은 줄여서 올린다 (' + Math.round(big.was/1024) + 'KB → ' + Math.round(big.now/1024) + 'KB)');
  ok(big.w === 1600, '긴 쪽을 1600 으로 맞춘다');
  ok(big.type === 'image/jpeg', 'jpg 로 내보낸다');

  // ── 이미 작은 사진은 건드리지 않는다 ────────────────────────────
  const small = await pg.evaluate(async (mk) => {
    const f = await eval(mk)(200, 150, '작은사진.jpg');
    const s = await shrinkImage(f, { maxDim: 1600, quality: 0.82 });
    return { same: s === f, size: f.size };
  }, MAKE);
  ok(small.same, '이미 작은 사진은 그대로 둔다 (건드릴 이득이 없다)');

  // ── 아이폰 사진은 알아본다 ──────────────────────────────────────
  const know = await pg.evaluate(() => ({
    byType: isHeic({ name:'IMG_0001', type:'image/heic' }),
    byType2: isHeic({ name:'IMG_0001', type:'image/heif' }),
    byName: isHeic({ name:'IMG_0001.HEIC', type:'' }),
    byName2: isHeic({ name:'사진.heif', type:'application/octet-stream' }),
    jpg: isHeic({ name:'a.jpg', type:'image/jpeg' }),
    png: isHeic({ name:'a.png', type:'image/png' }),
  }));
  ok(know.byType && know.byType2, '형식으로 알아본다 (heic · heif)');
  ok(know.byName && know.byName2, '이름으로도 알아본다 (형식이 비어 오는 기기가 있다)');
  ok(!know.jpg && !know.png, '보통 사진을 아이폰 사진으로 잘못 보지 않는다');

  // ── 아이폰 사진은 작아도 jpg 로 다시 내보낸다 ───────────────────
  //  이름만 .heic 이고 속은 jpeg 인 파일로 '사파리가 읽는 경우' 를 흉낸다
  const heic = await pg.evaluate(async (mk) => {
    const f = await eval(mk)(300, 200, 'IMG_0001.HEIC', 'image/heic');
    const s = await shrinkImage(f, { maxDim: 1600, quality: 0.82 });
    return { name: s.name, type: s.type, same: s === f };
  }, MAKE);
  console.log('     아이폰 사진:', JSON.stringify(heic));
  ok(!heic.same, '아이폰 사진은 작아도 그냥 두지 않는다');
  ok(/\.jpg$/i.test(heic.name), '이름을 .jpg 로 바꾼다');
  ok(heic.type === 'image/jpeg', '속도 jpg 로 바꾼다');

  //  투명을 지키라고 해도 아이폰 사진은 jpg 다 (png 로 내보내면 또 못 연다)
  const keep = await pg.evaluate(async (mk) => {
    const f = await eval(mk)(300, 200, 'IMG_0002.heic', 'image/heic');
    const s = await shrinkImage(f, { maxDim: 512, keepAlpha: true, minSize: 60 * 1024 });
    return { name: s.name, type: s.type };
  }, MAKE);
  ok(keep.type === 'image/jpeg' && /\.jpg$/i.test(keep.name), '투명을 지키는 자리에서도 아이폰 사진은 jpg 로 간다');

  // ── 끝내 못 바꾼 아이폰 사진은 아예 안 올린다 ───────────────────
  //  그대로 올리면 올린 사람 말고는 아무도 못 봅니다. 자리만 차지합니다.
  const blocked = await pg.evaluate(async () => {
    const f = new File([new Uint8Array(1000)], 'IMG_9999.heic', { type: 'image/heic' });
    const r = await sb.storage.from('messenger').upload('chat/ch1/IMG_9999.heic', f, {});
    return { err: (r && r.error && r.error.message) || '', body: document.body.textContent };
  });
  ok(/jpg 로 바꾸지 못했어요/.test(blocked.err), '못 바꾼 아이폰 사진은 올리지 않는다');
  ok(/높은 호환성/.test(blocked.err), '아이폰에서 어떻게 바꾸는지까지 알려 준다');
  ok(/설정 → 카메라 → 포맷/.test(blocked.body), '그 말이 화면에도 뜬다');

  //  보통 사진은 막히지 않는다
  const pass = await pg.evaluate(async (mk) => {
    const f = await eval(mk)(100, 100, 'ok.jpg');
    const r = await sb.storage.from('messenger').upload('chat/ch1/ok.jpg', f, {});
    return (r && r.error && r.error.message) || '';
  }, MAKE);
  ok(pass === '', '보통 사진은 그대로 올라간다');

  await pg.close(); await b.close(); done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
