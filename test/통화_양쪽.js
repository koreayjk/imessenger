//  📞 전화 — 두 기기를 실제로 붙여 보는 시험
//
//  "받아지기는 하는데 서로가 안들려" 를 재기 위한 시험입니다. 화면만 보는
//  시험으로는 소리가 흐르는지 알 수 없어서, 크로미움 두 창을 띄워 진짜
//  RTCPeerConnection 끼리 붙이고 **소리 꾸러미가 실제로 오가는지**
//  (getStats 의 packetsReceived) 를 셉니다.
//
//  바깥으로 나가는 길은 여전히 막혀 있습니다. 쪽지(SDP·ICE)는 Supabase
//  방송이 아니라 시험이 들고 있는 가짜 줄로 건네줍니다 — 그래서 '엔진' 만
//  재게 됩니다. 그 가짜 줄을 일부러 늦게 붙이거나 쪽지를 떨어뜨려서,
//  방송이 샐 때도 전화가 붙는지까지 봅니다.
const fs = require('fs'), path = require('path');
const H = require('./_harness.js');
const { openApp, ok, done } = H;

function findChrome() {
  for (const r of ['/opt/pw-browsers']) {
    let dirs = [];
    try { dirs = fs.readdirSync(r).filter(d => /^chromium/.test(d)).sort().reverse(); } catch (_) {}
    for (const d of dirs) for (const nm of ['chrome-linux64/chrome', 'chrome-linux/chrome']) {
      const p = path.join(r, d, nm); if (fs.existsSync(p)) return p;
    }
  }
  return '/usr/bin/chromium';
}
function pw() {
  for (const c of ['/opt/node-tools/node_modules/playwright-core', 'playwright-core', 'playwright']) {
    try { return require(c); } catch (_) {}
  }
  throw new Error('playwright 를 못 찾았습니다');
}

//  ── 가짜 쪽지 줄 ──────────────────────────────────────────────────
//  sb.channel() 이 돌려주는 것만 바꿔 끼웁니다. callSignalJoin / callSend /
//  callOnSignal / callReoffer 는 진짜 그대로 돕니다.
//    joinDelay : 줄이 '붙었다' 고 알려 주기까지 걸리는 시간
//    dropFirst : 이 종류의 첫 쪽지를 한 번 떨어뜨린다 ('offer' 등)
async function wire(from, to, tag, log, o) {
  const name = '__out_' + tag;
  await from.exposeFunction(name, (s) => {
    const p = JSON.parse(s);
    const ty = (p && p.payload && p.payload.type) || '?';
    log.push(tag + '→ ' + ty);
    to.evaluate((x) => { if (window.__in) window.__in(x); }, s).catch(() => {});
  });
  await from.evaluate(({ name, joinDelay, dropFirst }) => {
    const hs = [];
    window.__dropped = 0;
    window.__lost = 0;
    window.__in = (s) => {
      const m = JSON.parse(s);
      hs.forEach(h => { try { h({ payload: m.payload }); } catch (_) {} });
    };
    sb.channel = () => {
      let joined = false, dropped = false;
      const ch = {
        on(ev, f, cb) { if (ev === 'broadcast') hs.push(cb); return ch; },
        subscribe(cb) {
          setTimeout(() => { joined = true; if (cb) cb('SUBSCRIBED'); }, joinDelay || 0);
          return ch;
        },
        send(p) {
          //  줄에 못 붙은 채 보내면 방송은 허공으로 갑니다 — 그걸 그대로 흉냅니다.
          if (!joined) { window.__lost++; return Promise.resolve('timeout'); }
          const ty = p && p.payload && p.payload.type;
          if (dropFirst && ty === dropFirst && !dropped) { dropped = true; window.__dropped++; return Promise.resolve('ok'); }
          window[name](JSON.stringify(p));
          return Promise.resolve('ok');
        },
      };
      return ch;
    };
    sb.removeChannel = () => {};
  }, { name, joinDelay: (o && o.joinDelay) || 0, dropFirst: (o && o.dropFirst) || '' });
}

//  한 통화를 끝까지 이어 본다. { A, B, log } 를 돌려준다.
async function place(b, o = {}) {
  const A = await openApp(b, { as: 'teacher' });   // 거는 쪽 (김선생)
  const B = await openApp(b, { as: 'student' });   // 받는 쪽 (홍길동)
  const log = [];
  await wire(A, B, 'A', log, o.a);
  await wire(B, A, 'B', log, o.b);

  await A.evaluate(() => { window.__DB.calls = []; startCall('s1'); });
  await A.waitForTimeout(1100);
  const id = await A.evaluate(() => CALL && CALL.id);
  if (!id) throw new Error('거는 쪽이 전화를 못 만들었습니다');

  //  받는 쪽 표에도 그 전화가 있어야 합니다 (callMark 가 0행이면 못 받습니다)
  await B.evaluate((cid) => {
    window.__DB.calls = [{ id: cid, community_id: 'c1', caller_id: 'me', callee_id: 's1',
                           status: 'ringing', kind: 'audio', created_at: new Date().toISOString() }];
    onCallRing({ id: cid, caller_id: 'me', callee_id: 's1', status: 'ringing',
                 created_at: new Date().toISOString() });
  }, id);
  await B.waitForTimeout(500);
  await B.evaluate(() => acceptCall());
  await B.waitForTimeout(700);
  //  거는 쪽은 표가 바뀐 소식으로도 제안을 시작한다 (실시간 줄 대신 바로 먹인다)
  await A.evaluate((cid) => { onCallChanged({ id: cid, status: 'accepted', caller_id: 'me', callee_id: 's1' }); }, id);
  return { A, B, log, id };
}

const linked = async (pg, secs) => {
  for (let i = 0; i < (secs || 15) * 4; i++) {
    const s = await pg.evaluate(() => CALL && CALL.net);
    if (s === 'connected') return true;
    await pg.waitForTimeout(250);
  }
  return false;
};
const flow = async (pg) => pg.evaluate(() => {
  if (!CALL || !CALL.pc) return null;
  return CALL.pc.getStats().then((s) => {
    let inb = 0, out = 0;
    s.forEach((r) => {
      if (r.type === 'inbound-rtp'  && r.kind === 'audio') inb = r.packetsReceived || 0;
      if (r.type === 'outbound-rtp' && r.kind === 'audio') out = r.packetsSent || 0;
    });
    return { inb, out };
  });
});

(async () => {
  const b = await pw().chromium.launch({
    executablePath: findChrome(),
    args: [
      '--use-fake-device-for-media-stream',   // 마이크 대신 삐- 소리를 넣어 준다
      '--use-fake-ui-for-media-stream',       // 허락 창을 자동으로 누른다
      '--autoplay-policy=no-user-gesture-required',
      '--disable-features=WebRtcHideLocalIpsWithMdns',
    ],
  });

  // ══ ① 평소 ════════════════════════════════════════════════════════
  console.log('\n  ── ① 평소 — 줄이 바로 붙는다');
  {
    const { A, B, log } = await place(b);
    const aUp = await linked(A), bUp = await linked(B);
    ok(aUp, '거는 쪽 — 소리 길이 붙었다 (connected)');
    ok(bUp, '받는 쪽 — 소리 길이 붙었다 (connected)');
    ok(log.includes('B→ ready'),  '받는 쪽이 ready 를 보냈다');
    ok(log.includes('A→ offer'),  '거는 쪽이 offer 를 보냈다');
    ok(log.includes('B→ answer'), '받는 쪽이 answer 를 보냈다');
    ok(log.filter(x => x === 'A→ ice').length > 0, '거는 쪽이 길(ice)을 보냈다');
    ok(log.filter(x => x === 'B→ ice').length > 0, '받는 쪽이 길(ice)을 보냈다');

    const dirs = async (pg) => pg.evaluate(() => CALL && CALL.pc && CALL.pc.getTransceivers().map(tr => ({
      cur: tr.currentDirection, snd: !!(tr.sender && tr.sender.track), rcv: !!(tr.receiver && tr.receiver.track) })));
    const aTx = await dirs(A), bTx = await dirs(B);
    ok(!!aTx && aTx.length === 1 && aTx[0].cur === 'sendrecv', '거는 쪽 — 소리줄이 양방향(sendrecv)');
    ok(!!bTx && bTx.length === 1 && bTx[0].cur === 'sendrecv', '받는 쪽 — 소리줄이 양방향(sendrecv)');
    ok(!!aTx && aTx[0].snd && aTx[0].rcv, '거는 쪽 — 내 마이크도 상대 소리도 걸렸다');
    ok(!!bTx && bTx[0].snd && bTx[0].rcv, '받는 쪽 — 내 마이크도 상대 소리도 걸렸다');

    await A.waitForTimeout(2500);
    const aF = await flow(A), bF = await flow(B);
    console.log('     꾸러미 — 거는 쪽', JSON.stringify(aF), '· 받는 쪽', JSON.stringify(bF));
    ok(!!aF && aF.out > 0, '거는 쪽 — 내 목소리를 내보내고 있다');
    ok(!!bF && bF.out > 0, '받는 쪽 — 내 목소리를 내보내고 있다');
    ok(!!aF && aF.inb > 0, '거는 쪽 — 상대 목소리가 들어오고 있다');
    ok(!!bF && bF.inb > 0, '받는 쪽 — 상대 목소리가 들어오고 있다');

    const el = async (pg) => pg.evaluate(() => {
      const a = document.getElementById('call-audio');
      if (!a) return null;
      const st = a.srcObject;
      return { has: !!st, tracks: st ? st.getAudioTracks().length : 0,
               live: st ? st.getAudioTracks().every(x => x.readyState === 'live') : false,
               paused: a.paused, muted: a.muted, srcAttr: a.getAttribute('src'),
               shown: getComputedStyle(a).display };
    });
    const aE = await el(A), bE = await el(B);
    ok(!!aE && aE.has && aE.tracks === 1 && aE.live, '거는 쪽 — 소리틀에 상대 소리가 걸렸다');
    ok(!!bE && bE.has && bE.tracks === 1 && bE.live, '받는 쪽 — 소리틀에 상대 소리가 걸렸다');
    ok(!!aE && !aE.paused && !aE.muted, '거는 쪽 — 소리틀이 멈춰 있지 않다');
    ok(!!bE && !bE.paused && !bE.muted, '받는 쪽 — 소리틀이 멈춰 있지 않다');
    ok(!!aE && aE.shown !== 'none', '소리틀이 화면에서 지워지지 않았다 (아이폰이 안 틀어 준다)');
    ok(!!aE && aE.srcAttr === null, '잠금풀이용 src 가 치워졌다');

    // ── 화면에 적히는 진단 줄 ────────────────────────────────────────
    await A.waitForTimeout(1200);
    const diag = await A.evaluate(() => {
      const d = document.getElementById('call-diag'), q = document.getElementById('call-quiet');
      return { d: d && d.textContent.trim(), q: q && q.style.display };
    });
    console.log('     진단 줄:', diag.d);
    ok(!!diag.d && /쪽지 ↑[1-9]/.test(diag.d), '진단 — 보낸 쪽지 수가 적힌다');
    ok(!!diag.d && /↓[1-9]/.test(diag.d), '진단 — 받은 쪽지 수가 적힌다');
    ok(!!diag.d && /줄 SUBSCRIBED/.test(diag.d), '진단 — 쪽지줄이 붙었다고 적힌다');
    ok(!!diag.d && /상태 connected/.test(diag.d), '진단 — 길 상태가 적힌다');
    ok(!!diag.d && /소리 ↑[1-9][0-9]* ↓[1-9]/.test(diag.d), '진단 — 소리 꾸러미 수가 적힌다');
    ok(!!diag.d && /내 마이크 [1-9][0-9]*%/.test(diag.d), '진단 — 내 마이크가 소리를 받고 있다고 적힌다');
    ok(diag.q === 'none', '진단 — 잘 들리면 까닭 줄은 숨는다');

    await A.close(); await B.close();
  }

  // ══ ② 쪽지줄이 늦게 붙는다 ════════════════════════════════════════
  //  subscribe() 는 바로 끝나지 않습니다. 그 사이에 보낸 쪽지는 허공으로
  //  갑니다 — 그게 '받아지는데 안 들리는' 모습 그대로였습니다.
  console.log('\n  ── ② 쪽지줄이 2초 늦게 붙는다 (모아 두고 뒤에 보내야 한다)');
  {
    const { A, B, log } = await place(b, { a: { joinDelay: 2000 }, b: { joinDelay: 2000 } });
    const aUp = await linked(A, 20), bUp = await linked(B, 20);
    const lost = await A.evaluate(() => window.__lost) + await B.evaluate(() => window.__lost);
    console.log('     허공으로 간 쪽지:', lost, '· 오간 순서:', log.join(', '));
    ok(lost === 0, '붙기 전에는 한 통도 안 내보냈다 (모아 뒀다)');
    ok(log.includes('A→ offer') && log.includes('B→ answer'), '모아 둔 제안·답이 뒤에 건너갔다');
    ok(aUp && bUp, '줄이 늦게 붙어도 전화는 붙는다');
    await A.waitForTimeout(2200);
    const aF = await flow(A), bF = await flow(B);
    ok(!!aF && aF.inb > 0 && !!bF && bF.inb > 0, '양쪽에 소리가 들어온다');
    await A.close(); await B.close();
  }

  // ══ ③ 첫 제안이 사라진다 ══════════════════════════════════════════
  //  실시간 방송은 '닿았는지' 를 알려주지 않습니다. 한 통이 새면 영영
  //  안 들립니다 — 답이 없으면 같은 제안을 다시 보내야 합니다.
  console.log('\n  ── ③ 첫 제안(offer)이 사라진다 (다시 보내야 한다)');
  {
    const { A, B, log } = await place(b, { a: { dropFirst: 'offer' } });
    const dropped = await A.evaluate(() => window.__dropped);
    ok(dropped === 1, '첫 제안을 일부러 떨어뜨렸다');
    const aUp = await linked(A, 20), bUp = await linked(B, 20);
    console.log('     오간 순서:', log.join(', '));
    ok(log.filter(x => x === 'A→ offer').length >= 1, '제안을 다시 보냈다');
    ok(aUp && bUp, '한 통이 새도 전화는 붙는다');
    await A.waitForTimeout(2200);
    const aF = await flow(A), bF = await flow(B);
    ok(!!aF && aF.inb > 0 && !!bF && bF.inb > 0, '양쪽에 소리가 들어온다');
    await A.close(); await B.close();
  }

  // ══ ④ 왜 조용한지를 화면이 말해 주는가 ════════════════════════════
  //  '안 들려요' 가 늘 같은 말로만 보이면 어디가 막혔는지 알 수 없습니다.
  //  세 가지를 가려서 적어야 합니다.
  console.log('\n  ── ④ 조용한 까닭을 화면이 가려서 적는다');
  {
    const { A, B } = await place(b);
    await linked(A); await A.waitForTimeout(1200);
    const say = async (patch) => A.evaluate((pt) => {
      Object.assign(CALL, pt.c);
      if (pt.why !== undefined) _callTurnWhy = pt.why;
      callTick();
      const q = document.getElementById('call-quiet');
      return q && q.style.display === 'none' ? '' : (q ? q.textContent.trim() : null);
    }, patch);

    const w1 = await say({ c: { linked: false, sigIn: 0 } });
    ok(/쪽지가 아직 안 오갔/.test(w1 || ''), '쪽지가 안 오갔다 → 그렇게 적는다');

    const w2 = await say({ c: { linked: false, sigIn: 3, hasTurn: false },
                           why: 'CF_TURN_KEY_ID/CF_TURN_API_TOKEN 이 없습니다' });
    ok(/중계\(TURN\)가 꺼져 있습니다/.test(w2 || '') && /CF_TURN_KEY_ID/.test(w2 || ''),
       '중계가 꺼졌다 → 까닭까지 적는다');

    const w3 = await say({ c: { linked: false, sigIn: 3, hasTurn: true } });
    ok(/소리 길을 찾는 중/.test(w3 || ''), '중계는 있는데 아직 못 붙었다 → 찾는 중이라고 적는다');

    const w4 = await say({ c: { linked: true, aud: { inb: 0, out: 500, mic: 0.3 } } });
    ok(/상대 소리가 아직 안 와요/.test(w4 || ''), '붙었는데 소리가 안 온다 → 그렇게 적는다');

    const w5 = await say({ c: { linked: true, needTap: true, aud: { inb: 900, out: 900, mic: 0.3 } } });
    ok(/이 기기가 막았어요/.test(w5 || ''), '소리는 오는데 기기가 막았다 → 눌러 달라고 적는다');

    const w6 = await say({ c: { linked: true, needTap: false, playing: true,
                                startedAt: Date.now() - 20000, rlvMax: 0.3, micMax: 0,
                                aud: { inb: 900, out: 900, mic: 0 } } });
    ok(/제 마이크가 내내 조용해요/.test(w6 || ''), '내 마이크가 조용하다 → 그렇게 적는다');

    const w7 = await say({ c: { micMax: 0.3 } });
    ok(w7 === '', '다 괜찮으면 아무 말도 안 한다');

    await A.close(); await B.close();
  }

  // ══ ⑤ 잠금풀이 틀과 소리틀은 따로여야 한다 ════════════════════════
  //  한 틀을 돌려쓰면 사파리에서 그 틀이 스트림으로 안 돌아옵니다 —
  //  play() 는 되었다 하고 paused 도 false 인데 소리만 안 납니다.
  console.log('\n  ── ⑤ 잠금풀이 틀과 소리틀이 따로다');
  {
    const { A, B } = await place(b);
    await linked(A); await A.waitForTimeout(1500);
    const e = await A.evaluate(() => {
      const a = document.getElementById('call-audio'), u = document.getElementById('call-unlock');
      return {
        aSrc: a && a.getAttribute('src'), aStream: !!(a && a.srcObject),
        aHad: !!(a && a.currentSrc), uSrc: u && (u.getAttribute('src') || '').slice(0, 15),
        same: !!(a && u && a === u),
      };
    });
    console.log('     소리틀/잠금틀:', JSON.stringify(e));
    ok(!e.same, '두 틀이 서로 다른 것이다');
    ok(e.aSrc === null && e.aHad === false, '소리틀은 src 를 한 번도 먹지 않았다');
    ok(e.aStream, '소리틀에는 스트림만 걸려 있다');
    ok(/^data:audio\/wav/.test(e.uSrc || ''), '잠금풀이는 딴 틀이 맡았다');
    await A.close(); await B.close();
  }

  // ══ ⑥ 틀이 멈추면 새로 만든다 ═════════════════════════════════════
  console.log('\n  ── ⑥ 꾸러미는 오는데 틀이 멈췄다 → 틀을 새로 만든다');
  {
    const { A, B } = await place(b);
    await linked(A); await A.waitForTimeout(1500);
    await A.evaluate(() => {
      const a = document.getElementById('call-audio');
      a.dataset.old = '1';          // 이 틀이 버려지는지 보려고 표를 붙인다
      a.pause();                    // 막힌 틀을 흉내 낸다
    });
    await A.waitForTimeout(4800);   // 3초를 봐주고 새로 만든다
    const r = await A.evaluate(() => {
      const a = document.getElementById('call-audio');
      return { old: a && a.dataset.old, paused: a && a.paused,
               tracks: a && a.srcObject ? a.srcObject.getAudioTracks().length : 0,
               rebuilt: CALL && CALL.rebuilt,
               quiet: (document.getElementById('call-quiet') || {}).textContent };
    });
    console.log('     ', JSON.stringify(r));
    ok(r.old === undefined, '막힌 틀을 버렸다');
    ok((r.rebuilt || 0) >= 1, '틀을 새로 만들었다고 세어 둔다');
    ok(r.paused === false, '새 틀이 돌고 있다');
    ok(r.tracks === 1, '새 틀에도 상대 소리가 걸렸다');
    await A.close(); await B.close();
  }

  // ══ ⑦ 조용한 쪽이 어디인지 가린다 ═════════════════════════════════
  console.log('\n  ── ⑦ 상대 마이크가 조용한 것과 내 마이크가 조용한 것을 가린다');
  {
    const { A, B } = await place(b);
    await linked(A); await A.waitForTimeout(1500);
    const say = async (pt) => A.evaluate((x) => {
      Object.assign(CALL, x);
      callTick();
      const q = document.getElementById('call-quiet');
      return q && q.style.display === 'none' ? '' : (q ? q.textContent.trim() : null);
    }, pt);

    const old = Date.now() - 20000;
    const w1 = await say({ startedAt: old, linked: true, needTap: false, playing: true,
                           rlvMax: 0, micMax: 0.3, aud: { inb: 900, out: 900, mic: 0.3, rlv: 0 } });
    ok(/상대 마이크가 내내 조용/.test(w1 || ''), '상대가 조용하면 상대 쪽을 보라고 한다');

    const w2 = await say({ startedAt: old, rlvMax: 0.3, micMax: 0 });
    ok(/제 마이크가 내내 조용/.test(w2 || ''), '내가 조용하면 내 쪽을 보라고 한다');

    const w3 = await say({ startedAt: old, rlvMax: 0.3, micMax: 0.3, playing: false });
    ok(/이 기기가 안 틀고 있어요/.test(w3 || ''), '틀이 멈췄으면 틀 탓이라고 한다');

    const w4 = await say({ startedAt: old, playing: true, rlvMax: 0.3, micMax: 0.3 });
    ok(w4 === '', '다 괜찮으면 아무 말도 안 한다');

    const d = await A.evaluate(() => document.getElementById('call-diag').textContent.trim());
    console.log('     진단 줄:', d);
    ok(/상대 소리 30%/.test(d), '진단 — 상대 소리 크기가 적힌다');
    ok(/틀 ▶/.test(d), '진단 — 소리틀이 도는지 적힌다');

    await A.close(); await B.close();
  }

  // ══ ⑧ 마이크가 잠긴 채로도 전화는 붙는다 — 그걸 말해 줘야 한다 ═══════
  //  아이폰 앱은 마이크 허락이 없을 때 거절하지 않고 '조용한 마이크' 를
  //  내주는 일이 있습니다. 허락 창도 안 뜹니다. 그러면 전화는 멀쩡히 붙고
  //  내 목소리만 안 갑니다 — 오류가 하나도 없어서 찾을 길이 없었습니다.
  console.log('\n  ── ⑧ 마이크가 잠겨 있으면 화면이 그렇게 말한다');
  {
    const { A, B } = await place(b);
    await linked(A); await A.waitForTimeout(1500);

    const got = await A.evaluate(() => CALL && CALL.micTrack);
    console.log('     잡은 마이크:', JSON.stringify(got));
    ok(!!got && got.live === true && got.muted === false, '받은 마이크가 살아 있는지 들여다본다');
    ok(!!got && typeof got.label === 'string' && got.label.length > 0, '어느 마이크인지도 적어 둔다');

    const say = async (pt) => A.evaluate((x) => {
      Object.assign(CALL, x);
      callTick();
      const q = document.getElementById('call-quiet');
      return q && q.style.display === 'none' ? '' : (q ? q.textContent.trim() : null);
    }, pt);

    const w1 = await say({ linked: true, playing: true, startedAt: Date.now() - 20000,
                           rlvMax: 0.3, micMax: 0.3, micTrack: { label: 'x', live: true, muted: true } });
    ok(/마이크가 잠겨 있어요/.test(w1 || '') && /설정 → TCS → 마이크/.test(w1 || ''),
       '마이크가 잠겼으면 어디서 켜는지까지 알려 준다');
    const d1 = await A.evaluate(() => document.getElementById('call-diag').textContent.trim());
    ok(/내 마이크 \d+%🔒/.test(d1), '진단 줄에도 자물쇠가 붙는다');

    const w2 = await say({ micTrack: { label: 'x', live: false, muted: false } });
    ok(/마이크가 잠겨 있어요/.test(w2 || ''), '마이크 줄이 끊겨도 똑같이 알려 준다');

    const w3 = await say({ micTrack: { label: 'x', live: true, muted: false } });
    ok(w3 === '', '마이크가 멀쩡하면 아무 말도 안 한다');

    await A.close(); await B.close();
  }

  await b.close();
  done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
