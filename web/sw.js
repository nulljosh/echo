// ponytail: network-first for pages, cache-first for the hashed assets they name.
// Bump CACHE to evict everything a previous version stored.
const CACHE = "voxprint-v3";
const FILES = ["/", "/index.html", "/manifest.webmanifest"];

self.addEventListener("install", e => {
  // A single missing file fails the whole addAll, so tolerate misses.
  e.waitUntil(caches.open(CACHE)
    .then(c => Promise.all(FILES.map(f => c.add(f).catch(() => {}))))
    .then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

const save = (req, res) => {
  if (res.ok && res.type === "basic") {
    const copy = res.clone();
    caches.open(CACHE).then(c => c.put(req, copy));
  }
  return res;
};

self.addEventListener("fetch", e => {
  // Same-origin GETs only; APIs are cross-origin and stay network-only.
  if (e.request.method !== "GET" || new URL(e.request.url).origin !== location.origin) return;

  // HTML must never come from cache first: it names the hashed bundles, so one
  // stale page pins a whole stale build and the site stops shipping updates to
  // anyone who has already visited. Network first, cache only as an offline fallback.
  if (e.request.mode === "navigate") {
    e.respondWith(
      fetch(e.request)
        .then(res => save(e.request, res))
        .catch(() => caches.match(e.request, { ignoreSearch: true })
          .then(hit => hit || caches.match(FILES[0])))
    );
    return;
  }

  // Everything else is content-hashed, so a cache hit is always the right file.
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(hit => hit ||
      fetch(e.request).then(res => save(e.request, res)))
  );
});
