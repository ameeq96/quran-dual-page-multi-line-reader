self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  event.waitUntil((async () => {
    let data;
    try { data = event.data.json(); } catch (_) { return; }
    if (!data || typeof data !== 'object' || !Number.isFinite(data.atUtcMs) ||
        !Number.isFinite(data.expiresAt) || data.expiresAt < Date.now() ||
        data.atUtcMs > Date.now() + 30000 || data.expiresAt > data.atUtcMs + 120000 ||
        typeof data.eventId !== 'string' || data.eventId.length > 120 ||
        typeof data.instanceId !== 'string' || !/^[A-Za-z0-9_-]{32}$/.test(data.instanceId) ||
        !/^quran-prayer-[a-f0-9]{32}$/.test(data.tag)) return;
    const home = new URL('../', self.location.href);
    const windows = (await self.clients.matchAll({type: 'window', includeUncontrolled: true}))
      .filter((client) => new URL(client.url).origin === home.origin);
    for (const client of windows) client.postMessage({...data, type: 'PRAYER_PUSH'});
    await self.registration.showNotification(
      typeof data.title === 'string' ? data.title.slice(0, 120) : 'Prayer reminder', {
        body: typeof data.body === 'string' ? data.body.slice(0, 300) : 'It is time for prayer.',
        tag: data.tag, renotify: false,
        silent: data.silent === true || windows.some((client) => client.visibilityState === 'visible'),
        icon: new URL('../icons/Icon-192.png', self.location.href).href,
        badge: new URL('../icons/Icon-192.png', self.location.href).href,
      });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const home = new URL('../', self.location.href);
  event.waitUntil(self.clients.matchAll({type: 'window', includeUncontrolled: true}).then(async (windows) => {
    for (const client of windows) {
      if (new URL(client.url).origin === home.origin && 'focus' in client) return client.focus();
    }
    return self.clients.openWindow(home.href);
  }));
});
