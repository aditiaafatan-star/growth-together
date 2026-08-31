// Service worker sederhana buat Growth Together Mobile.
// Strategi: network-first (selalu coba internet dulu biar data selalu terbaru),
// baru fallback ke cache kalau lagi offline -- jadi app-shell-nya tetap kebuka.

const CACHE_NAME = 'growth-together-v1';
const APP_SHELL = ['./app.html', './manifest.json', './icon.svg', './icon-maskable.svg'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // biarin request ke Supabase (API/realtime) lewat langsung, gak usah dicache/diintersep
  if (event.request.url.includes('supabase.co')) return;

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
