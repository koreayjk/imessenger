//  🖥 맥 앱이 마이크를 쓸 자격을 제대로 갖췄는가
//
//  맥에는 문이 두 겹입니다 — 화면(웹)이 묻는 허락과, 맥 자체의 허락.
//  맥 쪽이 막혀 있으면 맥은 거절하지 않고 **조용한 마이크**를 내줍니다.
//  전화는 멀쩡히 붙고 내 목소리만 안 갑니다. 오류가 하나도 안 납니다.
//  그래서 '안 되는 걸 못 알아채는' 쪽으로 다시 새지 않게 못 박아 둡니다.
//
//  브라우저를 안 띄웁니다. main.js 를 가짜 일렉트론 위에서 돌려서
//  **진짜 권한 손잡이**가 무엇을 열어 주는지 직접 물어봅니다.
const fs = require('fs'), path = require('path');
const { ok, done } = require('./_harness.js');

const ROOT = path.resolve(__dirname, '..');
const D = path.join(ROOT, 'desktop');
const ORIGIN = 'https://koreayjk.github.io';

// ── ① 서류 세 장 ─────────────────────────────────────────────────
const pkg = JSON.parse(fs.readFileSync(path.join(D, 'package.json'), 'utf8'));
const ent = fs.readFileSync(path.join(D, 'build/entitlements.mac.plist'), 'utf8');

const info = (pkg.build && pkg.build.mac && pkg.build.mac.extendInfo) || {};
ok(/마이크/.test(info.NSMicrophoneUsageDescription || ''),
   'Info.plist 에 마이크 쓰임말이 있다 (없으면 맥이 묻지를 않는다)');
ok(/카메라/.test(info.NSCameraUsageDescription || ''),
   'Info.plist 에 카메라 쓰임말이 있다');
ok(/audio-input/.test(ent),
   'entitlements 에 audio-input 이 있다 (없으면 hardened runtime 이 막는다)');
ok(pkg.build.mac.hardenedRuntime === true,
   'hardened runtime 은 켜 둔 채다 (공증에 필요하다)');
ok((pkg.build.mac.entitlements || '').includes('entitlements.mac.plist'),
   '그 entitlements 를 실제로 쓰고 있다');

// ── ② 진짜 권한 손잡이에게 물어본다 ──────────────────────────────
//  main.js 를 가짜 일렉트론 위에서 돌린다. 창은 안 뜬다.
function loadMain(macStatus) {
  const seen = { req: null, chk: null, dialogs: [], asked: [], opened: [] };
  let status = macStatus || 'granted';
  const el = {
    app: {
      requestSingleInstanceLock: () => true,
      on() {}, quit() {},
      whenReady: () => Promise.resolve(),
      getPath: () => '/tmp', getVersion: () => '0.0.0',
    },
    BrowserWindow: function () {
      const session = {
        setPermissionRequestHandler: (f) => { seen.req = f; },
        setPermissionCheckHandler: (f) => { seen.chk = f; },
      };
      const webContents = {
        session, on() {}, setWindowOpenHandler() {},
        getUserAgent: () => 'UA', setUserAgent() {}, getURL: () => ORIGIN + '/imessenger/',
      };
      Object.assign(this, {
        webContents, maximize() {}, once() {}, on() {}, loadURL() {},
        isDestroyed: () => false, isMinimized: () => false, isMaximized: () => false,
        getBounds: () => ({ x: 0, y: 0, width: 1, height: 1 }), show() {},
      });
    },
    shell: { openExternal: (u) => seen.opened.push(u) },
    Menu: { buildFromTemplate: () => ({}), setApplicationMenu() {} },
    dialog: {
      showMessageBox: (o) => { seen.dialogs.push(o); return Promise.resolve({ response: 0 }); },
    },
    systemPreferences: {
      getMediaAccessStatus: (k) => { seen.asked.push('status:' + k); return status; },
      askForMediaAccess: (k) => { seen.asked.push('ask:' + k); return Promise.resolve(status === 'granted'); },
    },
  };
  el.BrowserWindow.getAllWindows = () => [{}];
  const fake = (m) => {
    if (m === 'electron') return el;
    if (m === 'node:path') return path;
    if (m === 'node:fs') return { readFileSync() { throw new Error('없음'); }, writeFileSync() {} };
    return require(m);
  };
  const src = fs.readFileSync(path.join(D, 'main.js'), 'utf8');
  new Function('require', 'module', 'exports', '__dirname', 'process', src)(
    fake, { exports: {} }, {}, D, Object.assign({}, process, { platform: 'darwin' }));
  return seen;
}

const ask = (seen, perm, url, det) => new Promise((res) => {
  seen.req({ getURL: () => url }, perm, res, Object.assign({ requestingUrl: url }, det || {}));
});

(async () => {
  //  맥이 허락한 경우
  const g = loadMain('granted');
  await new Promise(r => setTimeout(r, 30));          // whenReady().then 이 돌 틈을 준다
  ok(typeof g.req === 'function', '권한 손잡이를 달았다 (안 달면 일렉트론이 거의 다 열어 준다)');
  ok(typeof g.chk === 'function', '물어보기만 하는 쪽도 막아 뒀다');

  ok(await ask(g, 'media', ORIGIN + '/imessenger/', { mediaTypes: ['audio'] }),
     '우리 주소에서 온 마이크 요청은 열어 준다');
  ok(g.asked.some(x => /microphone/.test(x)), '열어 주기 전에 맥에게 먼저 물어본다');

  ok(!(await ask(g, 'media', 'https://evil.example.com/', { mediaTypes: ['audio'] })),
     '다른 주소에서 온 마이크 요청은 막는다');
  ok(!(await ask(g, 'geolocation', ORIGIN + '/imessenger/')),
     '안 쓰는 권한은 우리 주소라도 막는다');
  ok(!(await ask(g, 'openExternal', ORIGIN + '/imessenger/')),
     '컴퓨터를 건드리는 권한은 막는다');
  ok(g.chk({}, 'media', ORIGIN) === true && g.chk({}, 'media', 'https://evil.example.com') === false,
     '물어보기도 우리 주소일 때만 참이라고 한다');

  //  맥이 막고 있는 경우 — 조용히 지나가면 안 된다
  const d = loadMain('denied');
  await new Promise(r => setTimeout(r, 30));
  ok(!(await ask(d, 'media', ORIGIN + '/imessenger/', { mediaTypes: ['audio'] })),
     '맥이 막고 있으면 열어 주지 않는다');
  ok(d.dialogs.length === 1, '막혔다고 화면에 알려 준다 (조용히 지나가지 않는다)');
  const box = d.dialogs[0] || {};
  ok(/마이크/.test(box.message || ''), '무엇이 막혔는지 적는다');
  ok(/개인정보 보호 및 보안/.test(box.detail || ''), '어디서 켜는지까지 알려 준다');
  ok(/목소리가 상대에게 가지 않/.test(box.detail || ''), '그대로 두면 어떻게 되는지도 적는다');
  ok(d.opened.some(u => /Privacy_Microphone/.test(u)), '설정 열기를 누르면 그 자리로 간다');

  //  두 번 세 번 뜨면 전화를 걸 수가 없다
  await ask(d, 'media', ORIGIN + '/imessenger/', { mediaTypes: ['audio'] });
  ok(d.dialogs.length === 1, '같은 말을 두 번 띄우지는 않는다');

  //  예전 버릇 — 손잡이가 없던 때로 돌아가지 않았는지
  const src = fs.readFileSync(path.join(D, 'main.js'), 'utf8');
  ok(/nodeIntegration:\s*false/.test(src) && /contextIsolation:\s*true/.test(src)
     && /sandbox:\s*true/.test(src), '받아온 화면에 컴퓨터를 건드릴 힘은 여전히 없다');

  done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
