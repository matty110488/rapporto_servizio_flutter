importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "dummy",
  authDomain: "dummy",
  projectId: "dummy",
  messagingSenderId: "dummy",
  appId: "dummy"
});

const messaging = firebase.messaging();