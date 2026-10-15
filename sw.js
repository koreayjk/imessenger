// TCS 서비스워커 — 앱을 닫아도 알림이 오게 한다.
//
//  브라우저는 앱이 꺼진 뒤에도 이 파일을 깨워서 푸시를 받습니다.
//  그래서 여기에는 앱 코드가 하나도 없습니다 — 알림을 띄우고,
//  누르면 열어 주는 일만 합니다.
//
//  화면 파일을 미리 받아 두지(캐시) 않습니다. 1.7MB 짜리 index.html 을
//  캐시하면 고쳐도 옛 화면이 남아, 고쳐 드려도 안 바뀐다는 말을 듣게
//  됩니다. 알림만 맡깁니다.

const SCOPE_URL = new URL('./', self.registration.scope).href;

self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (_) {
    try { d = { body: event.data.text() }; } catch (__) { d = {}; }
  }
  const title = d.title || 'TCS';
  const opts = {
    body: d.body || '새 메시지가 왔어요',
    icon: d.icon || (SCOPE_URL + 'tcs_icon-192.png?v=2'),
    badge: d.badge || (SCOPE_URL + 'tcs_icon-192.png?v=2'),
    // 같은 방 알림은 하나로 덮어쓴다. 스무 개가 쌓이면 알림이 아니라 방해다.
    tag: d.tag || 'tcs',
    renotify: false,
    data: { channelId: d.channelId || null, url: d.url || SCOPE_URL },
    timestamp: Date.now(),
  };
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const target = data.url || SCOPE_URL;
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // 이미 열려 있는 창이 있으면 그 창을 쓴다. 누를 때마다 새 탭이 열리면 곤란하다.
    for (const c of all) {
      if (c.url.startsWith(SCOPE_URL)) {
        try { await c.focus(); } catch (_) {}
        try { c.postMessage({ type: 'tcs-open-channel', channelId: data.channelId }); } catch (_) {}
        return;
      }
    }
    const url = data.channelId ? (target + '#ch=' + data.channelId) : target;
    try { await self.clients.openWindow(url); } catch (_) {}
  })());
});
