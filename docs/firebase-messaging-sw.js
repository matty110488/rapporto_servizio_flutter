importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

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
  const title = payload?.notification?.title || 'Nuova notifica';
  const body = payload?.notification?.body || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
  });
});
