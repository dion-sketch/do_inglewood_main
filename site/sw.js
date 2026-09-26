// Do Inglewood — service worker for game-day push alerts.
// Only handles push + notification taps (no offline caching), so it can never
// serve a stale copy of the app. Deploy it next to index.html (whole site/ folder).

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener('push', function (e) {
  var d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { body: e.data && e.data.text() }; }
  e.waitUntil(self.registration.showNotification(d.title || 'Do Inglewood', {
    body: d.body || '',
    icon: d.icon || undefined,
    tag: d.tag || undefined,           // one pregame + one after-hours alert per event
    data: { url: d.url || './' }
  }));
});

self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  var url = new URL((e.notification.data && e.notification.data.url) || './', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].url.indexOf(self.registration.scope) === 0 && 'navigate' in list[i]) {
        return list[i].navigate(url).then(function (c) { return c && c.focus(); });
      }
    }
    return self.clients.openWindow(url);
  }));
});
