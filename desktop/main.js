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
const { app, BrowserWindow, shell, Menu, dialog } = require('electron');
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
    app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
  });
  // 맥에서는 창을 닫아도 앱이 남는 것이 보통이다 (독 아이콘을 다시 누르면 열린다)
  app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
}
