'use strict';

const workerUrl = new URL(self.location.href);
const baseUrl = new URL(self.registration.scope);
const version = workerUrl.searchParams.get('v');
const renderer = workerUrl.searchParams.get('renderer') === 'chromium'
  ? 'canvaskit/chromium/' : 'canvaskit/';
const shellPrefix = 'quran-reader-shell-v17-';
const shellCacheName = `${shellPrefix}${version}-${renderer.includes('chromium') ? 'chromium' : 'full'}`;
const pageCacheName = 'quran-reader-scans-v1';
const indexUrl = new URL('index.html', baseUrl).href;
const shellFiles = [
  'main.dart.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'quick_reader.css',
  'robots.txt',
  'sitemap.xml',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/assets/quran_pages/quran_navigation_index_16_line.json'
];

function relativePath(url) {
  return url.origin === baseUrl.origin && url.pathname.startsWith(baseUrl.pathname)
    ? url.pathname.slice(baseUrl.pathname.length) : null;
}

function isPublicAsset(url) {
  const path = relativePath(url);
  return path !== null && (path === 'main.dart.js' || path === 'manifest.json' ||
    path === 'quick_reader.css' ||
    path === 'robots.txt' || path === 'sitemap.xml' ||
    path === 'favicon.png' || path.startsWith('assets/') ||
    path.startsWith('icons/') || path.startsWith('canvaskit/'));
}

function isScan(url) {
  return relativePath(url)?.startsWith('assets/assets/asset_packs/') &&
    /\.(webp|png|jpe?g)$/i.test(url.pathname);
}

function isAzanAsset(url) {
  return /^assets\/assets\/prayer_audio\/(adhan_(general|fajr)\.mp3|ATTRIBUTION\.json)$/.test(relativePath(url) ?? '');
}

function isCacheableResponse(response) {
  return response.ok && !response.redirected &&
    (response.type === 'basic' || response.type === 'default');
}

function surahPageUrl(url) {
  const path = relativePath(url);
  if (path === null || !/^surah\/[a-z0-9-]+\/(?:index\.html)?$/.test(path)) return null;
  return new URL(path.replace(/index\.html$/, ''), baseUrl).href;
}

async function networkFirstSurah(request, targetUrl) {
  const cache = await caches.open(shellCacheName);
  let response;
  try {
    response = await fetch(request);
  } catch (error) {
    const cached = await cache.match(targetUrl);
    if (cached) return cached;
    throw error;
  }
  if (response.status === 200 && isCacheableResponse(response)) {
    try {
      await cache.put(targetUrl, response.clone());
    } catch (_) {
      // Storage limits must not interrupt online reading.
    }
  }
  return response;
}

async function cacheFirst(request) {
  const url = new URL(request.url);
  const cache = await caches.open(isScan(url) ? pageCacheName : shellCacheName);
  const cached = await cache.match(request);
  if (cached) return cached;
  const response = await fetch(isAzanAsset(url)
    ? new Request(request, { cache: 'reload' }) : request);
  if (isCacheableResponse(response)) {
    try {
      await cache.put(request, response.clone());
    } catch (_) {
      // Storage limits must not interrupt online reading.
    }
  }
  return response;
}

let bundledAssetUrls;
let fullCacheBatch;

async function loadBundledAssetUrls() {
  if (bundledAssetUrls) return bundledAssetUrls;
  const response = await cacheFirst(new Request(new URL('assets/AssetManifest.bin.json', baseUrl)));
  if (!response.ok) throw new Error('The bundled asset manifest is unavailable.');
  const encoded = await response.json();
  if (typeof encoded !== 'string') throw new Error('Invalid bundled asset manifest.');
  const bytes = Uint8Array.from(atob(encoded), (character) => character.charCodeAt(0));
  const data = new DataView(bytes.buffer);
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let offset = 0;
  function requireBytes(count) {
    if (!Number.isInteger(count) || count < 0 || count > bytes.length - offset) {
      throw new Error('Truncated bundled asset manifest.');
    }
  }
  function readSize() {
    requireBytes(1);
    const marker = bytes[offset++];
    if (marker < 254) return marker;
    const length = marker === 254 ? 2 : 4;
    requireBytes(length);
    const value = length === 2 ? data.getUint16(offset, true) : data.getUint32(offset, true);
    offset += length;
    return value;
  }
  function readValue(depth = 0) {
    if (depth > 8) throw new Error('Invalid bundled asset manifest depth.');
    requireBytes(1);
    const type = bytes[offset++];
    if (type === 7) {
      const length = readSize();
      requireBytes(length);
      const value = decoder.decode(bytes.subarray(offset, offset + length));
      offset += length;
      return value;
    }
    if (type !== 12 && type !== 13) throw new Error('Unsupported bundled asset manifest value.');
    const length = readSize();
    requireBytes(length * (type === 13 ? 2 : 1));
    const value = type === 13 ? new Map() : [];
    for (let index = 0; index < length; index++) {
      if (type === 13) value.set(readValue(depth + 1), readValue(depth + 1));
      else value.push(readValue(depth + 1));
    }
    return value;
  }
  const manifest = readValue();
  if (!(manifest instanceof Map) || offset !== bytes.length || manifest.size === 0) {
    throw new Error('Invalid bundled asset manifest contents.');
  }
  const assetUrls = [...manifest.keys()].map((key) => {
    if (typeof key !== 'string' || (!key.startsWith('assets/') && !key.startsWith('packages/'))) {
      throw new Error('Invalid bundled asset path.');
    }
    const url = new URL(`assets/${key}`, baseUrl);
    if (!isPublicAsset(url)) throw new Error('Bundled asset is outside the reader.');
    return url.href;
  });
  const sitemap = await cacheFirst(new Request(new URL('sitemap.xml', baseUrl)));
  if (!sitemap.ok) throw new Error('The Surah sitemap is unavailable.');
  const locations = [...(await sitemap.text()).matchAll(/<loc>\s*([^<]+)\s*<\/loc>/g)]
    .map((match) => new URL(match[1].trim()));
  const surahUrls = locations.filter((url) => surahPageUrl(url) === url.href);
  if (locations.length !== 115 || surahUrls.length !== 114 ||
      locations.filter((url) => url.href === baseUrl.href).length !== 1 ||
      new Set(surahUrls.map((url) => url.href)).size !== 114) {
    throw new Error('Invalid Surah sitemap contents.');
  }
  bundledAssetUrls = [...assetUrls, ...surahUrls.map((url) => url.href)];
  return bundledAssetUrls;
}

async function cachedAssetUrls() {
  const urls = new Set();
  for (const name of [shellCacheName, pageCacheName]) {
    for (const request of await (await caches.open(name)).keys()) urls.add(request.url);
  }
  return urls;
}

async function saveRequiredAsset(url) {
  const cache = await caches.open(isScan(new URL(url)) ? pageCacheName : shellCacheName);
  if (await cache.match(url)) return;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120000);
  try {
    const isSurah = surahPageUrl(new URL(url)) !== null;
    const response = await fetch(new Request(url, {
      cache: isSurah ? 'no-cache' : isAzanAsset(new URL(url)) ? 'reload' : 'force-cache', signal: controller.signal
    }));
    if (!isCacheableResponse(response) || (isSurah && response.status !== 200)) {
      throw new Error('A bundled Quran file is unavailable.');
    }
    await cache.put(url, response);
  } finally {
    clearTimeout(timeout);
  }
}

async function runFullCacheBatch() {
  const urls = await loadBundledAssetUrls();
  const cached = await cachedAssetUrls();
  const missing = urls.filter((url) => !cached.has(url)).slice(0, 4);
  let cursor = 0;
  let failure;
  async function downloadNext() {
    while (!failure && cursor < missing.length) {
      const url = missing[cursor++];
      try {
        await saveRequiredAsset(url);
      } catch (error) {
        failure ??= error;
      }
    }
  }
  await Promise.all([downloadNext(), downloadNext()]);
  const saved = await cachedAssetUrls();
  const completed = urls.filter((url) => saved.has(url)).length;
  return {
    state: failure ? 'paused' : completed === urls.length ? 'ready' : 'downloading',
    completed,
    total: urls.length,
    reason: failure ? failure.name === 'QuotaExceededError' ? 'storage' : 'network' : ''
  };
}

async function activateLegacyReaderCache() {
  const active = self.registration.active;
  if (!active || typeof MessageChannel !== 'function') return;
  const legacy = await new Promise((resolve) => {
    const channel = new MessageChannel();
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      channel.port1.close();
      channel.port2.close();
      resolve(value);
    };
    const timeout = setTimeout(() => finish(false), 2000);
    channel.port1.onmessage = (event) => finish(
      event.data?.fullQuran === true && event.data?.readerLearningPortal !== true);
    channel.port1.onmessageerror = () => finish(false);
    try {
      active.postMessage({ type: 'READER_OFFLINE_CAPABILITIES' }, [channel.port2]);
    } catch (_) {
      finish(false);
    }
  });
  if (legacy) await self.skipWaiting();
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    if (!version || !/^[0-9]+$/.test(version)) throw new Error('Missing reader cache version.');
    const cache = await caches.open(shellCacheName);
    try {
      const index = await fetch(new Request(indexUrl, { cache: 'no-cache' }));
      const html = await index.clone().text();
      if (!isCacheableResponse(index) ||
          !html.includes(`const readerCacheVersion = "${version}"`)) {
        throw new Error('Reader files changed during offline setup.');
      }
      await cache.put(indexUrl, index);
      for (const file of shellFiles) {
        const request = new Request(new URL(file, baseUrl), { cache: 'no-cache' });
        const response = await fetch(request);
        if (!isCacheableResponse(response)) throw new Error(`Offline file is unavailable: ${file}`);
        await cache.put(request, response);
      }
      const latestIndex = await fetch(new Request(indexUrl, { cache: 'no-cache' }));
      if (!latestIndex.ok || (await latestIndex.text()) !== html) {
        throw new Error('Reader version changed during offline setup.');
      }
      await activateLegacyReaderCache();
    } catch (error) {
      await caches.delete(shellCacheName);
      throw error;
    }
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if ((name.startsWith(shellPrefix) || name.startsWith('quran-reader-shell-v1-') ||
          name.startsWith('quran-reader-shell-v2-') || name.startsWith('quran-reader-shell-v3-') ||
          name.startsWith('quran-reader-shell-v4-') || name.startsWith('quran-reader-shell-v5-') ||
          name.startsWith('quran-reader-shell-v6-') || name.startsWith('quran-reader-shell-v7-') ||
          name.startsWith('quran-reader-shell-v8-') || name.startsWith('quran-reader-shell-v9-') ||
          name.startsWith('quran-reader-shell-v10-') || name.startsWith('quran-reader-shell-v11-') ||
          name.startsWith('quran-reader-shell-v12-') || name.startsWith('quran-reader-shell-v13-') ||
          name.startsWith('quran-reader-shell-v14-') || name.startsWith('quran-reader-shell-v15-') ||
          name.startsWith('quran-reader-shell-v16-')) &&
          name !== shellCacheName) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.cache === 'no-store' ||
      request.headers.has('authorization')) return;
  const url = new URL(request.url);
  const path = relativePath(url);
  const appNavigation = path === '' || path === 'app' || path === 'app/' || path === 'index.html';
  const surahUrl = surahPageUrl(url);
  if (request.mode === 'navigate' && surahUrl) {
    event.respondWith(networkFirstSurah(request, surahUrl));
  } else if (request.mode === 'navigate' && appNavigation) {
    event.respondWith((async () => {
      const cache = await caches.open(shellCacheName);
      return (await cache.match(indexUrl)) || fetch(indexUrl);
    })());
  } else if (isPublicAsset(url)) {
    event.respondWith(cacheFirst(request));
  }
});

self.addEventListener('message', (event) => {
  if (event.data?.type === 'READER_OFFLINE_CAPABILITIES') {
    event.ports?.[0]?.postMessage({ fullQuran: true, flutterHome: true, seoPages: true, onPageSeo: true, prayerReminders: true, integratedInfo: true, inAppSurahs: true, worshipTools: true, worshipDialogFix: true, worshipCardStyle: true, properAzan: true, freshAzanAudio: true, qiblaKaabaMarker: true, fixedQiblaTarget: true, qiblaSessionResume: true, magneticNorthNotice: true, readerLearningPortal: true });
    return;
  }
  if (event.data?.type === 'CACHE_FULL_QURAN_BATCH') {
    const port = event.ports?.[0];
    if (!port) return;
    fullCacheBatch ??= runFullCacheBatch().finally(() => { fullCacheBatch = null; });
    event.waitUntil(fullCacheBatch.then((progress) => port.postMessage(progress)).catch((error) => {
      port.postMessage({ state: 'paused', completed: 0, total: 0,
        reason: error.name === 'QuotaExceededError' ? 'storage' : 'network' });
    }));
    return;
  }
  if (event.data?.type !== 'CACHE_VISITED_ASSETS' || !Array.isArray(event.data.urls)) return;
  event.waitUntil((async () => {
    for (const resource of [...new Set(event.data.urls)].slice(0, 200)) {
      try {
        const url = new URL(resource);
        if (isPublicAsset(url)) {
          await cacheFirst(new Request(url, { cache: 'force-cache' }));
        }
      } catch (_) {
        // A missing or failed optional asset must not invalidate the offline shell.
      }
    }
  })());
});
