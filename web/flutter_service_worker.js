// Self-unregistering service worker: cleans up legacy Flutter PWA caches and unregisters.
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(keys.map((key) => caches.delete(key)));
    }).then(() => {
      return self.registration.unregister();
    }).then(() => {
      return self.clients.matchAll({ type: 'window' });
    }).then((clients) => {
      for (const client of clients) {
        if (client.url && 'navigate' in client) {
          client.navigate(client.url);
        }
      }
    })
  );
});
