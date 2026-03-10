import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

const _webProxyUrl =
    'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

Future<void> initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    criticalAlert: false,
    provisional: false,
    carPlay: false,
  );
  print('[PUSH] Permission status: ${settings.authorizationStatus}');
  if (kIsWeb && _webVapidKey.isEmpty) {
    print(
      '[PUSH] FIREBASE_WEB_VAPID_KEY is empty. Web token generation will fail.',
    );
  }

  FirebaseMessaging.onMessage.listen((message) {
    // Foreground handling can be expanded later with local notifications.
    print('[PUSH] Foreground message: ${message.messageId}');
  });
}

Future<String?> getCurrentPushToken() async {
  Future<String?> readToken() {
    if (kIsWeb && _webVapidKey.isNotEmpty) {
      return FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey);
    }
    return FirebaseMessaging.instance.getToken();
  }

  for (var attempt = 1; attempt <= 5; attempt++) {
    final token = await readToken();
    if (token != null && token.isNotEmpty) {
      print('[PUSH] Token acquired at attempt $attempt');
      return token;
    }
    print('[PUSH] Token is null at attempt $attempt');
    await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
  }
  return null;
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
