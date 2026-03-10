import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

const _webProxyUrl =
    'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

Future<void> initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    criticalAlert: false,
    provisional: false,
    carPlay: false,
  );

  FirebaseMessaging.onMessage.listen((message) {
    // Foreground handling can be expanded later with local notifications.
    print('[PUSH] Foreground message: ${message.messageId}');
  });
}

Future<String?> getCurrentPushToken() async {
  if (kIsWeb && _webVapidKey.isNotEmpty) {
    return FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey);
  }
  return FirebaseMessaging.instance.getToken();
}

Future<void> sendTokenToBackend(String userId, String token) async {
  final payload = jsonEncode({
    'action': 'registerPushToken',
    'userId': userId,
    'token': token,
  });

  final res = await http.post(
    Uri.parse(_webProxyUrl),
    headers: {'Content-Type': 'application/json'},
    body: payload,
  );

  if (res.statusCode != 200) {
    throw Exception('Errore registrazione token push: ${res.body}');
  }
}
