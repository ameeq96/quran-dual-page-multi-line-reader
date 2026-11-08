import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';
const code = readFileSync(new URL('../web/reader-notifications/push-worker.js', import.meta.url), 'utf8');
function worker() {
  const handlers = new Map(); const notifications = []; const opened = [];
  const self = { location: { href: 'https://reader.test/app/reader-notifications/push-worker.js' },
    addEventListener: (name, fn) => handlers.set(name, fn), skipWaiting() {},
    registration: { showNotification: async (...args) => notifications.push(args) },
    clients: { matchAll: async () => [], openWindow: async (url) => opened.push(url) } };
  vm.runInNewContext(code, { self, URL });
  return { handlers, notifications, opened, self };
}
test('push handles malformed payload and fixed same-origin icon safely', async () => {
  const state = worker(); let done;
  state.handlers.get('push')({ data: { json: () => null }, waitUntil: (promise) => { done = promise; } });
  await done;
  assert.equal(state.notifications[0][0], 'Time for Quran');
  assert.equal(state.notifications[0][1].icon, 'https://reader.test/app/icons/Icon-192.png');
});
test('push truncates untrusted text and ignores untrusted notification tag', async () => {
  const state = worker(); let done;
  state.handlers.get('push')({ data: { json: () => ({ title: 'a'.repeat(500), body: 'b'.repeat(700), tag: 'arbitrary' }) }, waitUntil: (promise) => { done = promise; } });
  await done;
  assert.equal(state.notifications[0][0].length, 120);
  assert.equal(state.notifications[0][1].body.length, 300);
  assert.equal(state.notifications[0][1].tag, 'quran-reading');
});
test('notification click opens only the configured app, never a payload URL', async () => {
  const state = worker(); let done; let closed = false;
  state.handlers.get('notificationclick')({ notification: { close: () => { closed = true; }, data: { url: 'https://evil.test' } }, waitUntil: (promise) => { done = promise; } });
  await done;
  assert.equal(closed, true);
  assert.deepEqual(state.opened, ['https://reader.test/app/']);
});
