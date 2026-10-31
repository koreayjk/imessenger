// ════════════════════════════════════════════════════════════════════
//  TCS 맥 앱 (.dmg 로 나눠드리는 것)
//
//  이 앱은 화면을 제 안에 담아두지 않고 '살아 있는 주소' 를 띄웁니다.
//  그래서 제가 고친 것이 맥 앱에도 바로 반영되고, 고칠 때마다 .dmg 를
//  다시 만들어 나눠드릴 필요가 없습니다.
//
//  남의 서버에서 받아온 화면을 띄우는 것이므로, 그 화면에 컴퓨터를
//  건드릴 힘을 주지 않습니다 (sandbox·contextIsolation·nodeIntegration).
//  아이들이 쓰는 앱이라 이 부분은 느슨하게 두지 않습니다.
// ════════════════════════════════════════════════════════════════════
'use strict';
const { app, BrowserWindow, shell, Menu, dialog, systemPreferences } = require('electron');
const path = require('node:path');
const fs = require('node:fs');

const HOME = 'https://koreayjk.github.io/imessenger/';
const ORIGIN = new URL(HOME).origin;

// 창 크기·자리를 기억한다. 열 때마다 기본 크기로 돌아가면 쓰는 사람이 매번 맞춰야 한다.
const stateFile = () => path.join(app.getPath('userData'), 'window.json');
function loadState() {
  try { return JSON.parse(fs.readFileSync(stateFile(), 'utf8')); } catch (_) { return {}; }
}
function saveState(win) {
  try {
    if (!win || win.isDestroyed() || win.isMinimized()) return;
    const b = win.getBounds();
    fs.writeFileSync(stateFile(), JSON.stringify({ ...b, max: win.isMaximized() }));
  } catch (_) {}
}

let win = null;

function offlineHtml(why) {
  // 인터넷이 없을 때 하얀 화면이나 크롬 오류 대신 우리 말로 알려준다
  return 'data:text/html;charset=utf-8,' + encodeURIComponent(`
    <!doctype html><html lang="ko"><head><meta charset="utf-8"/>
    <style>
      :root{color-scheme:light dark}
      body{margin:0;height:100vh;display:grid;place-items:center;background:#eef2f8;
        font:400 15px/1.7 -apple-system,"Pretendard",system-ui,sans-serif;color:#1a2336}
      @media (prefers-color-scheme:dark){body{background:#0c1723;color:#e9f0f8}}
      .box{text-align:center;max-width:380px;padding:0 24px}
      h1{font-size:19px;font-weight:800;margin:0 0 8px}
      p{margin:0;color:#5d6b82;font-size:13.5px}
      code{font-size:11.5px;opacity:.6;display:block;margin-top:14px;word-break:break-all}
      button{margin-top:22px;height:44px;padding:0 22px;border:0;border-radius:999px;
        background:#1d3a5f;color:#fff;font:700 14px inherit;cursor:pointer}
    </style></head><body><div class="box">
      <div style="font-size:40px;margin-bottom:10px">📡</div>
      <h1>인터넷에 닿지 않아요</h1>
      <p>와이파이를 확인하고 다시 눌러주세요.</p>
      <button onclick="location.href='${HOME}'">다시 열기</button>
      <code>${String(why || '').slice(0, 120)}</code>
    </div></body></html>`);
}

//  🎙 전화에 쓸 마이크 — 맥에는 문이 두 겹이다.
//
//  ⚠️ 하나는 화면(웹)이 묻는 허락이고, 또 하나는 맥 자체의 허락입니다.
//     맥 쪽 허락이 없으면 맥은 거절하지 않고 **묻지도 않은 채 조용한
//     마이크**를 내줍니다. 그러면 전화는 멀쩡히 붙고 내 목소리만 상대에게
//     안 갑니다 — 오류가 하나도 안 나서 찾을 길이 없습니다.
//     (실제로 "상대편은 마이크 허락 창이 안 떴다" 로 나타났습니다)
//
//     그래서 ① 맥에게 먼저 물어보고 ② 우리 주소일 때만 열어 줍니다.
//     Info.plist 의 NSMicrophoneUsageDescription 과
//     entitlements 의 com.apple.security.device.audio-input 이
//     둘 다 있어야 이 물음이 뜹니다 — 하나라도 빠지면 조용히 막힙니다.
async function askMacFor(kind) {
  if (process.platform !== 'darwin') return true;
  try {
    if (!systemPreferences.getMediaAccessStatus) return true;
    const st = systemPreferences.getMediaAccessStatus(kind);
    if (st === 'granted') return true;
    if (st === 'denied' || st === 'restricted') {
      macBlocked(kind);
      return false;
    }
    const ok = await systemPreferences.askForMediaAccess(kind);
    if (!ok) macBlocked(kind);
    return !!ok;
  } catch (_) { return true; }   // 알 수 없으면 막지는 않는다
}

//  막혔으면 어디서 켜는지까지 알려 준다. '안 된다' 만으로는 못 고친다.
let _macWarned = {};
function macBlocked(kind) {
  if (_macWarned[kind]) return;
  _macWarned[kind] = true;
  const name = kind === 'camera' ? '카메라' : '마이크';
  try {
    dialog.showMessageBox({
      type: 'warning',
      message: `맥이 TCS의 ${name} 사용을 막고 있어요`,
      detail: `   사과 메뉴 →  시스템 설정 →  개인정보 보호 및 보안 →  ${name}
`
            + `에서 TCS 를 켜 주세요. 켜신 뒤 앱을 껐다 다시 열면 됩니다.

`
            + `이대로 두면 전화는 걸리는데 제 목소리가 상대에게 가지 않습니다.`,
      buttons: ['설정 열기', '나중에'],
      defaultId: 0,
    }).then((r) => {
      if (r.response !== 0) return;
      const pane = kind === 'camera' ? 'Privacy_Camera' : 'Privacy_Microphone';
      shell.openExternal('x-apple.systempreferences:com.apple.preference.security?' + pane);
    }, () => {});
  } catch (_) {}
}

// ── 🔄 저절로 새 판으로 ───────────────────────────────────────────
//
//  맥 앱은 화면만 받아오므로 웬만한 고침은 다시 깔 일이 없습니다. 그런데
//  **앱 자체**가 바뀔 때는(이번 마이크 자격처럼) 다시 깔아야 합니다. 쓰시는
//  분들께 파일을 일일이 전해 드릴 수는 없으니, 앱이 스스로 GitHub 릴리스를
//  보고 받아 둡니다.
//
//  ⚠️ 맥은 **서명된 앱만** 저절로 갈아끼웁니다. 서명·공증을 건너뛰면 조용히
//     실패합니다. 그리고 앱이 '응용 프로그램' 폴더에 있어야 합니다 — .dmg
//     안에서 바로 띄우면 못 바꿉니다.
//  ⚠️ 맥의 자동 업데이트는 .dmg 가 아니라 **.zip** 과 latest-mac.yml 을 봅니다.
//     package.json 의 mac.target 에 zip 이 같이 있어야 하는 까닭입니다.
let updater = null;
let _askedRestart = false;

function initUpdater(force) {
  if (!updater) {
    if (!force && !app.isPackaged) return;     // 개발 중에는 하지 않는다
    try { updater = require('electron-updater').autoUpdater; }
    catch (e) {
      //  꾸러미에 안 담겼다. 조용히 지나가면 '왜 업데이트가 안 되지' 로만 남는다.
      console.log('업데이트 도구를 못 찾았습니다 —', String((e && e.message) || e));
      return;
    }
    updater.autoDownload = true;          // 받아만 둔다. 갈아끼우는 건 아래에서 묻는다.
    updater.autoInstallOnAppQuit = true;  // 안 물어도, 끄실 때 저절로 바뀐다
    updater.on('error', (e) => {
      console.log('업데이트를 못 봤습니다 —', String((e && e.message) || e));
    });
    updater.on('update-downloaded', (info) => askRestart((info && info.version) || ''));
    //  켜 두고 쓰시는 분들을 위해 여섯 시간마다 한 번 더 본다
    setInterval(() => { try { updater.checkForUpdates(); } catch (_) {} }, 6 * 3600 * 1000);
  }
  try { return updater.checkForUpdates(); } catch (_) {}
}

//  받아는 뒀다. 쓰는 중에 갑자기 꺼지면 안 되니 물어보고 바꿉니다.
function askRestart(ver) {
  if (_askedRestart) return;
  _askedRestart = true;
  try {
    dialog.showMessageBox({
      type: 'info',
      message: `새 판 ${ver} 이 준비됐어요`,
      detail: '지금 다시 열면 바로 쓰실 수 있습니다.\n'
            + '나중에 하셔도 됩니다 — 앱을 끄실 때 저절로 바뀝니다.',
      buttons: ['지금 다시 열기', '나중에'],
      defaultId: 0, cancelId: 1,
    }).then((r) => {
      if (r && r.response === 0) { try { updater.quitAndInstall(); } catch (_) {} }
    }, () => {});
  } catch (_) {}
}

//  메뉴에서 손으로도 볼 수 있게. 기다리는 분께는 '지금 봐 주세요' 가 필요합니다.
function checkUpdatesByHand() {
  _askedRestart = false;
  const p = initUpdater(true);
  if (!p || !p.then) {
    try { dialog.showMessageBox({ type: 'info', message: '지금은 확인할 수 없어요',
      detail: '인터넷에 닿지 않거나, 아직 묶지 않은 앱입니다.', buttons: ['닫기'] }); } catch (_) {}
    return;
  }
  p.then((r) => {
    const v = r && r.updateInfo && r.updateInfo.version;
    if (v && v !== app.getVersion()) return;        // 받는 중 — 다 받으면 물어본다
    try { dialog.showMessageBox({ type: 'info', message: '이미 최신이에요',
      detail: `맥 앱 ${app.getVersion()}`, buttons: ['닫기'] }); } catch (_) {}
  }, (e) => {
    try { dialog.showMessageBox({ type: 'warning', message: '확인하지 못했어요',
      detail: String((e && e.message) || e).slice(0, 200), buttons: ['닫기'] }); } catch (_) {}
  });
}

function createWindow() {
  const s = loadState();
  win = new BrowserWindow({
    width: s.width || 1280, height: s.height || 860,
    x: s.x, y: s.y,
    minWidth: 380, minHeight: 520,
    title: 'TCS',
    backgroundColor: '#eef2f8',
    // 맥 기본 띠를 쓴다. hiddenInset 으로 띠를 없애면 신호등이 앱의
    // 왼쪽 줄(TCS 로고) 위에 얹히고, 창이 좁아져 그 줄이 사라지면
    // 본문 위로 올라앉는다. 28px 을 아끼려다 겹치는 것보다 낫다.
    show: false,
    webPreferences: {
      // 받아온 화면에 컴퓨터를 건드릴 힘을 주지 않는다
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      spellcheck: true,
    },
  });
  // 화면 코드가 '여기는 맥 앱이다' 를 알아볼 수 있게 표시를 남긴다.
  // 맥 앱에는 백그라운드 푸시가 없어서, 될 수 없는 것을 단추로 내밀면 안 된다.
  try {
    const ua = win.webContents.getUserAgent();
    if (!ua.includes('TCSDesktop')) win.webContents.setUserAgent(ua + ' TCSDesktop/' + app.getVersion());
  } catch (_) {}
  if (s.max) win.maximize();

  //  받아온 화면에 아무 힘이나 주지 않는다 — 우리 주소일 때만, 쓰는 것만.
  //  (일렉트론은 아무 손잡이도 안 달면 거의 다 그냥 열어 줍니다)
  const ses = win.webContents.session;
  const OKAY = ['media', 'audioCapture', 'videoCapture', 'notifications',
                'clipboard-sanitized-write', 'fullscreen'];
  const ours = (url) => { try { return new URL(url).origin === ORIGIN; } catch (_) { return false; } };
  ses.setPermissionRequestHandler(async (wc, perm, done, det) => {
    const url = (det && det.requestingUrl) || (wc && wc.getURL()) || '';
    if (!OKAY.includes(perm) || !ours(url)) return done(false);
    //  마이크·카메라는 맥에게도 물어야 진짜로 소리가 난다
    const kinds = (det && det.mediaTypes && det.mediaTypes.length) ? det.mediaTypes
                : perm === 'audioCapture' ? ['audio']
                : perm === 'videoCapture' ? ['video'] : [];
    for (const k of kinds) {
      if (!(await askMacFor(k === 'video' ? 'camera' : 'microphone'))) return done(false);
    }
    done(true);
  });
  ses.setPermissionCheckHandler((_wc, perm, origin) => OKAY.includes(perm) && ours(origin || ''));

  win.once('ready-to-show', () => win.show());
  ['resize', 'move', 'close'].forEach(e => win.on(e, () => saveState(win)));
  win.on('closed', () => { win = null; });

  // 우리 주소 밖으로는 앱 안에서 가지 않는다 — 진짜 브라우저로 넘긴다
  const outward = (url) => {
    try { if (/^https?:$/.test(new URL(url).protocol)) shell.openExternal(url); } catch (_) {}
  };
  win.webContents.setWindowOpenHandler(({ url }) => { outward(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => {
    try { if (new URL(url).origin !== ORIGIN) { e.preventDefault(); outward(url); } } catch (_) { e.preventDefault(); }
  });

  win.webContents.on('did-fail-load', (_e, code, desc, url, isMainFrame) => {
    if (!isMainFrame || code === -3) return;   // -3 은 '사용자가 멈춤'
    win.loadURL(offlineHtml(`${code} ${desc}`));
  });

  win.loadURL(HOME);
}

function buildMenu() {
  const t = Menu.buildFromTemplate([
    { label: 'TCS', submenu: [
      { label: 'TCS 정보', click: () => dialog.showMessageBox({
          type: 'info', message: 'TCS — Total Care System',
          detail: `맥 앱 ${app.getVersion()}\n화면은 늘 최신으로 받아옵니다.\n${HOME}`,
          buttons: ['닫기'] }) },
      { label: '업데이트 확인…', click: () => checkUpdatesByHand() },
      { type: 'separator' },
      { label: 'TCS 가리기', role: 'hide' },
      { label: '나머지 가리기', role: 'hideOthers' },
      { label: '모두 보기', role: 'unhide' },
      { type: 'separator' },
      { label: 'TCS 종료', role: 'quit' },
    ]},
    { label: '편집', submenu: [
      { label: '실행 취소', role: 'undo' }, { label: '다시 실행', role: 'redo' },
      { type: 'separator' },
      { label: '오려두기', role: 'cut' }, { label: '복사', role: 'copy' },
      { label: '붙여넣기', role: 'paste' }, { label: '모두 선택', role: 'selectAll' },
    ]},
    { label: '보기', submenu: [
      { label: '새로 고침', role: 'reload' },
      { label: '강제로 새로 고침', role: 'forceReload' },
      { type: 'separator' },
      { label: '실제 크기', role: 'resetZoom' },
      { label: '확대', role: 'zoomIn' }, { label: '축소', role: 'zoomOut' },
      { type: 'separator' },
      { label: '전체 화면', role: 'togglefullscreen' },
    ]},
    { label: '창', submenu: [
      { label: '최소화', role: 'minimize' }, { label: '확대/축소', role: 'zoom' },
      { type: 'separator' }, { label: '앞으로 가져오기', role: 'front' },
    ]},
    { label: '도움말', submenu: [
      { label: '웹에서 열기', click: () => shell.openExternal(HOME) },
    ]},
  ]);
  Menu.setApplicationMenu(t);
}

// 한 번에 하나만 뜨게. 두 번 누르면 이미 있는 창을 앞으로.
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
  app.whenReady().then(() => {
    buildMenu();
    createWindow();
    initUpdater();            // 저절로 새 판으로 — 파일을 일일이 전하지 않아도 되게
    app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
  });
  // 맥에서는 창을 닫아도 앱이 남는 것이 보통이다 (독 아이콘을 다시 누르면 열린다)
  app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
}
