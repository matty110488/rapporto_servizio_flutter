importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAWzGoDeQq2ggURZej6z8kEybDRI2z9z0M',
  appId: '1:302480518812:web:b7a1d23d05d601eb70c759',
  messagingSenderId: '302480518812',
  projectId: 'appkronos-1d181',
  authDomain: 'appkronos-1d181.firebaseapp.com',
  storageBucket: 'appkronos-1d181.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  if (payload && payload.notification) {
    return;
  }

  var title = 'Nuova notifica';
  var body = '';
  if (payload && payload.data) {
    if (payload.data.title) title = payload.data.title;
    if (payload.data.body) body = payload.data.body;
  }
  self.registration.showNotification(title, {
    body,
    icon: 'icons/Icon-192.png',
    data: payload && payload.data ? payload.data : {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  var garaId = event.notification.data && event.notification.data.garaId
    ? event.notification.data.garaId
    : '';
  var url = './';
  if (garaId) {
    url = './?garaId=' + encodeURIComponent(garaId);
  }
  event.waitUntil(clients.openWindow(url));
});
