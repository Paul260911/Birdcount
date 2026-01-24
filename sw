// BirdCount Service Worker
// Version 1.0.0

const CACHE_NAME = 'birdcount-v1.0.0';
const RUNTIME_CACHE = 'birdcount-runtime';

// Dateien die sofort gecacht werden sollen
const PRECACHE_URLS = [
  './',
  './birdcount_mit_arten_filter.html',
  './manifest.json'
];

// Installation - Cache wichtige Dateien
self.addEventListener('install', event => {
  console.log('[Service Worker] Installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('[Service Worker] Precaching app shell');
        return cache.addAll(PRECACHE_URLS);
      })
      .then(() => self.skipWaiting())
  );
});

// Aktivierung - Alte Caches löschen
self.addEventListener('activate', event => {
  console.log('[Service Worker] Activating...');
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME && cacheName !== RUNTIME_CACHE) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch - Network First mit Cache Fallback
self.addEventListener('fetch', event => {
  // Ignoriere non-GET requests
  if (event.request.method !== 'GET') return;
  
  // Ignoriere externe Requests (Firebase, etc.)
  if (!event.request.url.startsWith(self.location.origin)) {
    // Aber cache trotzdem externe Resources wie Leaflet, etc.
    if (event.request.url.includes('cdnjs.cloudflare.com') || 
        event.request.url.includes('unpkg.com') ||
        event.request.url.includes('tile.openstreetmap.org')) {
      event.respondWith(
        caches.open(RUNTIME_CACHE).then(cache => {
          return cache.match(event.request).then(response => {
            return response || fetch(event.request).then(fetchResponse => {
              cache.put(event.request, fetchResponse.clone());
              return fetchResponse;
            });
          });
        })
      );
    }
    return;
  }
  
  // Network First Strategie für eigene Files
  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Speichere erfolgreiche Responses im Cache
        if (response.status === 200) {
          const responseClone = response.clone();
          caches.open(RUNTIME_CACHE).then(cache => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Bei Netzwerkfehler: Versuche aus Cache zu laden
        return caches.match(event.request).then(response => {
          if (response) {
            return response;
          }
          
          // Wenn auch Cache nicht hilft: Offline-Seite
          if (event.request.mode === 'navigate') {
            return caches.match('./birdcount_mit_arten_filter.html');
          }
        });
      })
  );
});

// Background Sync - für Offline-Beobachtungen
self.addEventListener('sync', event => {
  console.log('[Service Worker] Background sync:', event.tag);
  
  if (event.tag === 'sync-observations') {
    event.waitUntil(syncObservations());
  }
});

async function syncObservations() {
  console.log('[Service Worker] Syncing offline observations...');
  // Hier könnte die Logik für Offline-Sync sein
  // Wird von der App aufgerufen wenn wieder online
}

// Push Notifications
self.addEventListener('push', event => {
  console.log('[Service Worker] Push received');
  
  const options = {
    body: event.data ? event.data.text() : 'Neue Benachrichtigung von BirdCount',
    icon: './icon-192.png',
    badge: './icon-192.png',
    vibrate: [200, 100, 200],
    tag: 'birdcount-notification',
    requireInteraction: false,
    actions: [
      {
        action: 'open',
        title: 'Öffnen'
      },
      {
        action: 'close',
        title: 'Schließen'
      }
    ]
  };
  
  event.waitUntil(
    self.registration.showNotification('BirdCount', options)
  );
});

// Notification Click
self.addEventListener('notificationclick', event => {
  console.log('[Service Worker] Notification clicked:', event.action);
  
  event.notification.close();
  
  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      clients.openWindow('./')
    );
  }
});

// Message Handler - Kommunikation mit App
self.addEventListener('message', event => {
  console.log('[Service Worker] Message received:', event.data);
  
  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(RUNTIME_CACHE).then(cache => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});

console.log('[Service Worker] Loaded and ready!');
