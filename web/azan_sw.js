/*
 * أذان ليبيا — notification service worker (registered with its own scope so
 * it does not interfere with Flutter's service worker).
 * Handles the "إيقاف الأذان" action button and tapping the notification.
 */
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) { event.waitUntil(self.clients.claim()); });

function allClients() {
  return self.clients.matchAll({ type: 'window', includeUncontrolled: true });
}

function broadcastStop() {
  return allClients().then(function (list) {
    list.forEach(function (c) { c.postMessage({ type: 'azan-stop' }); });
    return list;
  });
}

self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  if (event.action === 'stop') {
    event.waitUntil(broadcastStop());
    return;
  }

  // Tap on the notification body: bring the app to the front (azan keeps playing).
  event.waitUntil(allClients().then(function (list) {
    for (var i = 0; i < list.length; i++) {
      if ('focus' in list[i]) return list[i].focus();
    }
    return self.clients.openWindow(new URL('./', self.location.href).href);
  }));
});

// Swiping the notification away also stops the call.
self.addEventListener('notificationclose', function (event) {
  event.waitUntil(broadcastStop());
});
