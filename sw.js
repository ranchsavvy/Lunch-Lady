/* Lunch Lady offline helper.
 *
 * Keeps a copy of the app's own files on the phone so it opens with no
 * signal. It never touches feed data (that lives in the phone's local
 * storage, which this file can't see) and never handles requests to other
 * sites (the Ranch Savvy pull goes straight to the network as before).
 *
 * Update behavior: the app always opens instantly from the saved copy.
 * If there's any signal, it also quietly checks GitHub for a newer copy
 * and saves it for next time. So a new version shows up on the SECOND
 * open after you push it. No version numbers to bump in this file.
 */
const CACHE = 'lunchlady-app';
const FILES = ['./', './index.html', './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return; // other sites: hands off

  // Every page open is served as index.html (the app is one page).
  const key = req.mode === 'navigate' ? './index.html' : req;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(key, { ignoreSearch: true });

    // 'no-cache' = ask GitHub whether the file changed instead of trusting
    // the browser's 10-minute HTTP cache
    const fresh = fetch(req.mode === 'navigate' ? './index.html' : req, { cache: 'no-cache' })
      .then(res => {
        if (res && res.ok) cache.put(key, res.clone());
        return res;
      })
      .catch(() => null);

    if (cached) {
      event.waitUntil(fresh); // update in the background, don't wait on it
      return cached;
    }
    const res = await fresh;
    return res || new Response('Offline and not yet saved on this phone. Open the app once with signal.', {
      status: 503, headers: { 'Content-Type': 'text/plain' }
    });
  })());
});
