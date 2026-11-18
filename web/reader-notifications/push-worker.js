self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('push', (event) => {
  let data = {};
  try {
    const parsed = event.data ? event.data.json() : {};
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) data = parsed;
  } catch (_) { /* Use the default reminder. */ }
  const title = typeof data.title === 'string' ? data.title.slice(0, 120) : 'Time for Quran';
  const body = typeof data.body === 'string' ? data.body.slice(0, 300) : 'Read a few pages and revisit your Hifz revision queue.';
  const tag = typeof data.tag === 'string' && /^quran-reading-\d{4}-\d{2}-\d{2}$/.test(data.tag) ? data.tag : 'quran-reading';
  event.waitUntil(self.registration.showNotification(title, { body, tag,
    icon: new URL('../icons/Icon-192.png', self.location.href).href,
    badge: new URL('../icons/Icon-192.png', self.location.href).href,
    renotify: false,
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const home = new URL('../', self.location.href).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (clients) => {
    for (const client of clients) {
      if (client.url.startsWith(home) && 'focus' in client) return client.focus();
    }
    return self.clients.openWindow(home);
  }));
});
