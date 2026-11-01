//  📞 아이폰 전화 화면(CallKit) — 이어진 곳이 다 이어졌는가
//
//  여기서는 아이폰을 돌릴 수 없습니다. 그런데 이 기능은 **한 군데만
//  어긋나도 조용히 아무 일도 안 일어납니다** — 오류도 안 납니다.
//  그래서 네 조각(아이폰 코드 · 화면 · 서버 · 데이터베이스)이 서로
//  같은 말을 쓰고 있는지를 글로 읽어 맞춰 봅니다.
const fs = require('fs'), path = require('path');
const { launch, openApp, ok, done } = require('./_harness.js');

const R = (p) => fs.readFileSync(path.join(__dirname, '..', p), 'utf8');
const CORE = R('ios/App/App/TCSCallKit.swift');
const PLUG = R('ios/App/App/CallKitPlugin.swift');
const APPD = R('ios/App/App/AppDelegate.swift');
const PLIST = R('ios/App/App/Info.plist');
const WEB = R('index.html');
const SRV = R('supabase/functions/push-notify/index.ts');
const SQL = R('db/전화화면_CallKit_DB설치.sql');

// ── ① 아이폰이 깨어날 수 있는가 ─────────────────────────────────
ok(/<key>UIBackgroundModes<\/key>\s*<array>\s*<string>voip<\/string>/.test(PLIST),
   'Info.plist 에 voip 가 있다 (없으면 꺼진 앱이 전화로 못 깨어난다)');
ok(/TCSCallKit\.shared\.start\(\)/.test(APPD),
   '앱이 켜지자마자 전화 받을 채비를 한다 (플러그인을 기다리면 늦다)');
ok(/desiredPushTypes\s*=\s*\[\.voIP\]/.test(CORE), 'VoIP 푸시를 받겠다고 등록한다');

// ── ② 애플이 못 봐주는 자리 ─────────────────────────────────────
//  VoIP 푸시를 받으면 그 자리에서 반드시 전화를 알려야 합니다.
//  안 그러면 iOS 가 앱을 죽이고, 몇 번 반복되면 푸시를 아예 끊습니다.
const pushFn = CORE.slice(CORE.indexOf('didReceiveIncomingPushWith'));
const pushBody = pushFn.slice(0, pushFn.indexOf('\n}\n') + 3);
ok(/reportNewIncomingCall/.test(pushBody),
   'VoIP 푸시를 받으면 **그 자리에서** 전화를 알린다 (안 그러면 애플이 푸시를 끊는다)');
//  ⚠️ 맨 앞 guard 에도 completion() 이 있습니다(VoIP 가 아닌 푸시는 그냥 끝냅니다).
//     그걸 보고 '순서가 뒤집혔다' 고 읽으면 안 됩니다 — **마지막** 것을 봅니다.
ok(pushBody.lastIndexOf('completion()') > pushBody.indexOf('reportNewIncomingCall'),
   '알리고 **나서** 끝낸다 (순서가 뒤집히면 애플이 안 봐준다)');
ok(/callId.*as\? String.*\?\?\s*""/s.test(pushBody) || /\?\? ""/.test(pushBody),
   '쪽지가 이상해도 그냥 넘어가지 않는다 (빈 값으로라도 알린다)');

// ── ③ 소리는 건드리지 않는다 ────────────────────────────────────
//  CallKit 이 AVAudioSession 을 쥐면 웹뷰가 잡아 둔 마이크와 다툽니다.
//  '받았는데 안 들리는' 그 증상으로 이미 한 번 크게 고생했습니다.
const act = CORE.slice(CORE.indexOf('didActivate audioSession'));
const actBody = act.slice(0, act.indexOf('\n'));
ok(/\{\s*\}/.test(actBody), '소리 길에는 손대지 않는다 (웹뷰가 쥔 것을 뺏지 않는다)');
ok(!/setCategory|setActive|AVAudioSession\.sharedInstance/.test(CORE),
   'AVAudioSession 을 아예 만지지 않는다');

// ── ④ 네 조각이 같은 말을 쓰는가 ────────────────────────────────
ok(/jsName\s*=\s*"CallKit"/.test(PLUG), '플러그인 이름이 CallKit 이다');
ok(/Plugins\s*\|\|\s*\{\}\)\.CallKit/.test(WEB), '화면도 같은 이름으로 찾는다');
for (const ev of ['voipToken', 'answer', 'ended']) {
  ok(new RegExp(`emit\\("${ev}"`).test(CORE), `아이폰이 ${ev} 를 보낸다`);
  ok(new RegExp(`addListener\\('${ev}'`).test(WEB), `화면이 ${ev} 를 듣는다`);
}
ok(/retainUntilConsumed:\s*true/.test(PLUG),
   '화면이 늦게 떠도 흘려버리지 않는다 (잠금화면에서 바로 받으면 웹뷰가 아직 없다)');

// ── ⑤ 표가 저장되고, 서버가 그 길로 보내는가 ────────────────────
ok(/kind:\s*'ios_voip'/.test(WEB), '화면이 VoIP 표를 ios_voip 로 저장한다');
ok(/kind === 'ios_voip'/.test(SRV), '서버가 그 줄을 찾아 쓴다');
ok(/'apns-push-type':\s*'voip'/.test(SRV), "서버가 종류를 voip 로 보낸다");
ok(/APNS_BUNDLE_ID\}\.voip/.test(SRV), '서버가 주소 뒤에 .voip 를 붙인다');
ok(/kind in \('ios', 'ios_voip'\)/.test(SQL),
   '데이터베이스가 ios_voip 줄을 받아 준다 (안 넓히면 조용히 저장이 안 된다)');

//  전화 화면이 뜨는데 보통 알림까지 오면 두 번 울린다
ok(/hasVoip/.test(SRV) && /if \(hasVoip\) return;/.test(SRV),
   '전화 화면을 쓰는 기기에는 보통 알림을 겹쳐 보내지 않는다');

// ── ⑥ 통화가 끝나면 전화 화면도 내려가는가 ──────────────────────
ok(/ckEnd\(CALL && CALL\.id\)/.test(WEB), '통화가 끝나면 전화 화면도 내린다');
ok(/ckConnected\(CALL\.id\)/.test(WEB), '소리가 붙으면 전화 화면의 시간이 돈다');
ok(/_ckRang !== row\.id/.test(WEB), '전화 화면이 울리는 중이면 앱이 겹쳐 울리지 않는다');

// ── ⑦ 아이폰이 아닌 곳에서는 아무 일도 없어야 한다 ──────────────
(async () => {
  const b = await launch();
  const pg = await openApp(b, { as: 'teacher' });
  const r = await pg.evaluate(async () => {
    const before = document.body.innerHTML.length;
    const ck = callKit();
    await callKitInit();
    ckEnd('x'); ckConnected('x');       // 터지면 안 된다
    callInit();
    return { ck, grew: document.body.innerHTML.length - before };
  });
  ok(r.ck === null, '브라우저에서는 전화 화면을 찾지 않는다');
  ok(typeof r.grew === 'number', '브라우저에서 불러도 터지지 않는다');
  await pg.close(); await b.close();
  done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
