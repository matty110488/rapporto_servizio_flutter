(function () {
  'use strict';

  window.forceAppUpdate = async function () {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(
        registrations
          .filter(function (registration) {
            const worker = registration.active ||
              registration.waiting ||
              registration.installing;
            return worker && worker.scriptURL.includes('flutter_service_worker.js');
          })
          .map(function (registration) {
            return registration.unregister();
          })
      );
    }

    if ('caches' in window) {
      const cacheNames = await caches.keys();
      await Promise.all(
        cacheNames
          .filter(function (name) {
            return name === 'flutter-app-cache' ||
              name === 'flutter-temp-cache' ||
              name.startsWith('flutter-');
          })
          .map(function (name) {
            return caches.delete(name);
          })
      );
    }

    const target = new URL(window.location.href);
    target.searchParams.set('_app_update', Date.now().toString());
    window.location.replace(target.toString());
  };
})();
