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
function loadMain(macStatus, up) {
  const seen = { req: null, chk: null, dialogs: [], asked: [], opened: [], menu: null, up: null };
  let status = macStatus || 'granted';
  const el = {
    app: {
      requestSingleInstanceLock: () => true,
      on() {}, quit() {}, isPackaged: true,
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
    Menu: { buildFromTemplate: (t) => { seen.menu = t; return {}; }, setApplicationMenu() {} },
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
    if (m === 'electron-updater') {
      if (up === 'missing') throw new Error('Cannot find module');
      const ev = {};
      seen.up = {
        on: (k, f) => { ev[k] = f; },
        fire: (k, a) => ev[k] && ev[k](a),
        checks: 0, quit: 0, autoDownload: null, autoInstallOnAppQuit: null,
        checkForUpdates() { seen.up.checks++; return Promise.resolve({ updateInfo: { version: '1.2.0' } }); },
        quitAndInstall() { seen.up.quit++; },
      };
      return { autoUpdater: seen.up };
    }
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

  // ── ③ 저절로 새 판으로 ──────────────────────────────────────────
  //  파일을 일일이 전해 드릴 수는 없습니다. 앱이 스스로 받아 갈아끼워야 합니다.
  ok(!!(pkg.dependencies && pkg.dependencies['electron-updater']),
     'electron-updater 가 dependencies 에 있다 (devDependencies 면 안 담긴다)');
  ok((pkg.build.files || []).some(f => /node_modules/.test(f)),
     '꾸러미에 node_modules 를 담는다 (안 담으면 업데이트 도구를 못 찾는다)');
  const tg = JSON.stringify(pkg.build.mac.target || '');
  ok(/"zip"/.test(tg), 'zip 도 같이 만든다 (맥 자동 업데이트는 dmg 가 아니라 zip 을 본다)');
  ok(/"dmg"/.test(tg), 'dmg 도 그대로 만든다 (처음 받으실 때 쓴다)');
  const pub = JSON.stringify(pkg.build.publish || '');
  ok(/"github"/.test(pub) && /koreayjk/.test(pub) && /imessenger/.test(pub),
     '어디서 새 판을 받아오는지 적혀 있다');
  ok(/--publish/.test((pkg.scripts || {}).release || ''), '올리는 명령이 있다');

  const u = loadMain('granted');
  await new Promise(r => setTimeout(r, 30));
  ok(u.up && u.up.checks >= 1, '앱이 켜지면 새 판이 있는지 본다');
  ok(u.up && u.up.autoDownload === true, '있으면 미리 받아 둔다');
  ok(u.up && u.up.autoInstallOnAppQuit === true, '안 물어봐도 끄실 때 바뀐다');

  //  다 받았다 — 쓰는 중에 갑자기 꺼지면 안 되니 물어본다
  const before = u.dialogs.length;
  u.up.fire('update-downloaded', { version: '1.2.0' });
  await new Promise(r => setTimeout(r, 10));
  const up = u.dialogs[before] || {};
  ok(/새 판 1\.2\.0 이 준비됐어요/.test(up.message || ''), '다 받으면 알려 준다');
  ok(/나중에 하셔도 됩니다/.test(up.detail || ''), '지금 안 해도 된다고 말해 준다');
  ok((up.buttons || [])[0] === '지금 다시 열기', '지금 바꾸는 단추가 먼저다');
  await new Promise(r => setTimeout(r, 10));
  ok(u.up.quit === 1, '지금 다시 열기 를 누르면 갈아끼운다');

  //  두 번 세 번 물으면 일을 못 한다
  const n = u.dialogs.length;
  u.up.fire('update-downloaded', { version: '1.2.0' });
  await new Promise(r => setTimeout(r, 10));
  ok(u.dialogs.length === n, '같은 것을 두 번 묻지는 않는다');

  //  인터넷이 끊겨도 앱이 죽으면 안 된다
  let crashed = false;
  try { u.up.fire('error', new Error('net down')); } catch (_) { crashed = true; }
  ok(!crashed, '새 판을 못 봐도 앱은 멀쩡하다');
  ok(u.dialogs.length === n, '못 봤다고 사람을 귀찮게 하지는 않는다');

  //  메뉴에서 손으로도 볼 수 있어야 한다
  const tcs = (u.menu || []).find(x => x.label === 'TCS');
  ok(!!tcs && (tcs.submenu || []).some(x => /업데이트 확인/.test(x.label || '')),
     '메뉴에 업데이트 확인 이 있다');

  //  업데이트 도구가 안 담겼으면 — 조용히 지나가면 영영 모른다
  const m = loadMain('granted', 'missing');
  await new Promise(r => setTimeout(r, 30));
  ok(m.up === null, '도구가 없으면 없는 대로 둔다 (앱은 그대로 돈다)');

  //  예전 버릇 — 손잡이가 없던 때로 돌아가지 않았는지
  const src = fs.readFileSync(path.join(D, 'main.js'), 'utf8');
  ok(/nodeIntegration:\s*false/.test(src) && /contextIsolation:\s*true/.test(src)
     && /sandbox:\s*true/.test(src), '받아온 화면에 컴퓨터를 건드릴 힘은 여전히 없다');

  done();
})().catch(e => { console.log('  ❌ 터졌습니다 —', (e && e.stack) || e); process.exit(1); });
