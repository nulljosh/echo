// ponytail: cache-first over a fixed file list. Bump CACHE to ship an update.
const CACHE = "voxprint-v2";
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

self.addEventListener("fetch", e => {
  // Same-origin GETs only; APIs are cross-origin and stay network-only.
  if (e.request.method !== "GET" || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    caches.match(e.request, { ignoreSearch: true }).then(hit => hit ||
      fetch(e.request).then(res => {
        // Fill the cache as the app loads, so the hashed bundles the shell needs
        // are there the next time the network is not. Opaque/error responses are
        // not worth storing.
        if (res.ok && res.type === "basic") {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, copy));
        }
        return res;
      }).catch(() =>
        // A navigation offline with nothing cached still gets the app shell.
        e.request.mode === "navigate" ? caches.match(FILES[0]) : Promise.reject()
      )
    )
  );
});
