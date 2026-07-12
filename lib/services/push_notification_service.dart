import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../state/session_state.dart';

const _webProxyUrl =
    'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

class PushNotice {
  const PushNotice({required this.title, required this.body});

  final String title;
  final String body;
}

final _foregroundNotices = StreamController<PushNotice>.broadcast();
Stream<PushNotice> get foregroundPushNotices => _foregroundNotices.stream;

Future<void> initFirebaseMessaging() async {
  if (kIsWeb && _webVapidKey.isEmpty) {
    print(
      '[PUSH] FIREBASE_WEB_VAPID_KEY is empty. Web token generation will fail.',
    );
  }

  FirebaseMessaging.onMessage.listen((message) {
    print('[PUSH] Foreground message: ${message.messageId}');
    final title = message.notification?.title ?? 'Nuova notifica';
    final body = message.notification?.body ?? '';
    _foregroundNotices.add(PushNotice(title: title, body: body));
  });
}

Future<bool> notificationsAreEnabled() async {
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

Future<void> enableNotificationsForUser(String userId) async {
  if (kIsWeb && _webVapidKey.isEmpty) {
    throw StateError('Configurazione notifiche web non disponibile.');
  }
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    criticalAlert: false,
    provisional: false,
    carPlay: false,
  );
  final allowed =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  if (!allowed) throw StateError('Permesso notifiche non concesso.');

  final token = await getCurrentPushToken();
  if (token == null || token.isEmpty) {
    throw StateError('Token notifiche non disponibile.');
  }
  await sendTokenToBackend(userId, token);
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
  final sessionToken = globalSessionToken;
  if (sessionToken == null || sessionToken.isEmpty) return;
  final payload = jsonEncode({
    'action': 'registerPushToken',
    'userId': userId,
    'token': token,
  });

  final res = await http.post(
    Uri.parse(_webProxyUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $sessionToken',
    },
    body: payload,
  );

  if (res.statusCode != 200) {
    throw Exception('Errore registrazione token push: ${res.body}');
  }
}
