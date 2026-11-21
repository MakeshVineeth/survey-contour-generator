'use strict';
// Offline service worker for Survey Contour Generator.
//  * install:  precaches every entry of precache_manifest.json (flutter build web --web-content-hash)
//              except canvaskit/**, into a cache named after the manifest content (one cache per build).
//              A failed install deletes its partial cache, so the previous build keeps working.
//  * fetch:    content-hashed files (manifest `urlHashed`) and canvaskit/** -> cache-first;
//              every other file (stable URL across deploys) -> network-first with cache fallback.
//  * updates:  boot.js registers `sw.js?v=<manifest hash>`, so each deploy installs a new worker.
//  * canvaskit/** is NOT content-hashed with --no-web-resources-cdn, so it is cached only inside the
//              per-build cache (never shared across builds) and only the engine variant this browser
//              actually loads is stored (runtime caching + a 'cache-urls' message from the page).
//  * activate: deletes the caches of older builds (the newest cache is the live one).
const PREFIX = 'contourgen-';
const MANIFEST = 'precache_manifest.json';
const NETWORK_FIRST = new Set([
  '', 'index.html', 'flutter_bootstrap.js', 'flutter.js', 'manifest.json', 'version.json', 'sw.js', MANIFEST,
]);
const MATCH = { ignoreSearch: true };

const scopePath = new URL(self.registration.scope).pathname;
const relPath = (url) => {
  const p = new URL(url).pathname;
  return p.startsWith(scopePath) ? p.slice(scopePath.length) : null;
};

function hashString(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(16);
}

async function liveCacheName() {
  const keys = (await caches.keys()).filter((k) => k.startsWith(PREFIX));
  return keys.length ? keys[keys.length - 1] : null;
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const res = await fetch(MANIFEST, { cache: 'no-store' });
    if (!res.ok) throw new Error('precache manifest unavailable');
    const text = await res.text();
    const entries = JSON.parse(text).entries || [];
    const cacheName = PREFIX + hashString(text);
    await caches.delete(cacheName);
    const cache = await caches.open(cacheName);
    const urls = entries.map((e) => e.url).filter((u) => !u.startsWith('canvaskit/'));
    for (const extra of ['sw.js', MANIFEST]) if (!urls.includes(extra)) urls.push(extra);
    try {
      // 'reload' bypasses the HTTP cache so the stored copies match this build.
      await Promise.all(urls.map(async (u) => {
        const r = await fetch(new Request(u, { cache: 'reload' }));
        if (!r.ok) throw new Error('precache failed: ' + u);
        await cache.put(u, r);
      }));
      const root = await fetch(new Request('./', { cache: 'reload' }));
      if (!root.ok) throw new Error('precache failed: ./');
      await cache.put('./', root);
      await carryOverEngine(cache, cacheName, entries);
    } catch (e) {
      await caches.delete(cacheName);
      throw e;
    }
    await self.skipWaiting();
  })());
});

// The engine files (canvaskit/**) are cached lazily, so after an update they only
// exist in the previous build's cache, which activation deletes. Copy every
// engine file whose manifest hash is unchanged into the new cache so the app
// still starts offline right after an update.
async function carryOverEngine(cache, cacheName, entries) {
  const wanted = new Map();
  for (const e of entries) if (e.url.startsWith('canvaskit/')) wanted.set(e.url, e.hash);
  for (const key of await caches.keys()) {
    if (!key.startsWith(PREFIX) || key === cacheName) continue;
    const old = await caches.open(key);
    const oldManifest = await old.match(MANIFEST);
    if (!oldManifest) continue;
    const oldHashes = new Map();
    for (const e of JSON.parse(await oldManifest.text()).entries || []) oldHashes.set(e.url, e.hash);
    for (const req of await old.keys()) {
      const rel = relPath(req.url);
      if (!rel || !wanted.has(rel) || oldHashes.get(rel) !== wanted.get(rel)) continue;
      if (await cache.match(rel)) continue;
      const res = await old.match(req);
      if (res) await cache.put(rel, res);
    }
  }
}

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const live = await liveCacheName();
    for (const key of await caches.keys()) {
      if (key.startsWith(PREFIX) && key !== live) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.type !== 'cache-urls' || !Array.isArray(data.urls)) return;
  event.waitUntil((async () => {
    const name = await liveCacheName();
    if (!name) return;
    const cache = await caches.open(name);
    for (const u of data.urls) {
      try {
        if (new URL(u).origin !== self.location.origin) continue;
        const rel = relPath(u);
        if (!rel || !rel.startsWith('canvaskit/') || (await cache.match(rel))) continue;
        const r = await fetch(u);
        if (r.ok && r.status === 200 && r.type === 'basic') await cache.put(rel, r);
      } catch (_) { /* best effort */ }
    }
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (new URL(req.url).origin !== self.location.origin) return;
  const rel = relPath(req.url);
  if (rel === null) return;
  event.respondWith(route(req, rel));
});

// Cache-first is only safe for files whose URL changes when their content does
// (content-hashed) and for the engine files, which live in the per-build cache.
// Every other file (boot.js, icons, index.html, ...) keeps a stable URL across
// deploys, so it is network-first with the cached copy as the offline fallback.
async function route(req, rel) {
  if (req.mode === 'navigate') return networkFirst(req, './');
  if (NETWORK_FIRST.has(rel)) return networkFirst(req, rel || './');
  if (rel.startsWith('canvaskit/') || (await hashedUrls()).has(rel)) return cacheFirst(req, rel);
  return networkFirst(req, rel);
}

let hashedCache = { name: null, urls: new Set() };

// URLs flagged `urlHashed` in the live build's precache manifest (memoised per cache).
async function hashedUrls() {
  const name = await liveCacheName();
  if (!name) return new Set();
  if (hashedCache.name === name) return hashedCache.urls;
  const urls = new Set();
  try {
    const res = await (await caches.open(name)).match(MANIFEST);
    const entries = res ? (JSON.parse(await res.text()).entries || []) : [];
    for (const e of entries) if (e.urlHashed === true) urls.add(e.url);
  } catch (_) { /* treat everything as unhashed: always correct, just less offline-fast */ }
  hashedCache = { name, urls };
  return urls;
}

async function store(key, res) {
  const name = await liveCacheName();
  if (name) await (await caches.open(name)).put(key, res);
}

async function networkFirst(req, key) {
  try {
    const res = await fetch(req, { cache: 'no-cache' });
    if (res.ok && res.status === 200 && req.mode !== 'navigate') await store(key, res.clone());
    return res;
  } catch (e) {
    const hit = (await caches.match(key, MATCH)) || (await caches.match('./', MATCH));
    if (hit) return hit;
    throw e;
  }
}

async function cacheFirst(req, rel) {
  const hit = await caches.match(rel, MATCH);
  if (hit) return hit;
  const res = await fetch(req);
  // Only engine files are cached at runtime; everything else was precached, so an
  // unknown path (e.g. an SPA-fallback HTML answer) can never poison the cache.
  const cacheable = rel.startsWith('canvaskit/') && res.type === 'basic';
  if (cacheable && res.ok && res.status === 200 && !req.headers.has('range')) await store(rel, res.clone());
  return res;
}
