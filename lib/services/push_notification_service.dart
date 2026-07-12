import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/session_state.dart';

const _webProxyUrl =
    'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
const _webVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');
const _webMessagingServiceWorker =
    'firebase-cloud-messaging-push-scope/firebase-messaging-sw.js';
const _pushDeviceIdKey = 'push_device_id';

class PushNotificationSetupException implements Exception {
  const PushNotificationSetupException(this.userMessage, [this.cause]);

  final String userMessage;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return userMessage;
    return '$userMessage ($cause)';
  }
}

class PushNotice {
  PushNotice({
    required this.title,
    required this.body,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  final String title;
  final String body;
  final DateTime receivedAt;
}

class PushSendResult {
  const PushSendResult({
    required this.sent,
    required this.attempted,
    this.errors = const [],
  });

  final int sent;
  final int attempted;
  final List<String> errors;

  factory PushSendResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return PushSendResult(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      errors: rawErrors is List
          ? rawErrors.map((entry) => entry.toString()).toList()
          : const [],
    );
  }
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

Future<String> getPushDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_pushDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final generated =
      'dev_${DateTime.now().millisecondsSinceEpoch}_${base64UrlEncode(bytes)}';
  await prefs.setString(_pushDeviceIdKey, generated);
  return generated;
}

Future<bool> notificationsAreEnabled() async {
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

Future<void> enableNotificationsForUser(String userId) async {
  if (kIsWeb && _webVapidKey.isEmpty) {
    throw const PushNotificationSetupException(
      'Configurazione notifiche web non disponibile.',
    );
  }
  if (kIsWeb && !await FirebaseMessaging.instance.isSupported()) {
    throw const PushNotificationSetupException(
      'Questo browser non supporta le notifiche push. Su iPhone apri l\'app dall\'icona nella schermata Home e verifica di avere iOS 16.4 o superiore.',
    );
  }
  final NotificationSettings settings;
  try {
    settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      criticalAlert: false,
      provisional: false,
      carPlay: false,
    );
  } catch (e) {
    print('[PUSH] Permission request failed: $e');
    throw PushNotificationSetupException(
      'Permesso notifiche non disponibile. Su iPhone l\'app deve essere aperta dall\'icona nella schermata Home.',
      e,
    );
  }
  final allowed =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  if (!allowed) {
    throw const PushNotificationSetupException(
      'Permesso notifiche non concesso. Controlla le impostazioni notifiche dell\'app sul dispositivo.',
    );
  }

  final token = await getCurrentPushToken();
  if (token == null || token.isEmpty) {
    throw const PushNotificationSetupException(
      'Token notifiche non disponibile. Riprova dopo aver chiuso e riaperto l\'app dalla schermata Home.',
    );
  }
  await sendTokenToBackend(userId, token);
}

Future<PushSendResult> sendTestNotificationToCurrentDevice(
  String userId,
) async {
  final token = await getCurrentPushToken();
  if (token == null || token.isEmpty) {
    throw const PushNotificationSetupException(
      'Token notifiche non disponibile su questo dispositivo.',
    );
  }
  await sendTokenToBackend(userId, token);
  return _sendPushTestToBackend(userId, token);
}

Future<String?> getCurrentPushToken() async {
  Future<String?> readToken() {
    if (kIsWeb && _webVapidKey.isNotEmpty) {
      return FirebaseMessaging.instance.getToken(
        vapidKey: _webVapidKey,
        serviceWorkerScriptPath: _webMessagingServiceWorker,
      );
    }
    return FirebaseMessaging.instance.getToken();
  }

  for (var attempt = 1; attempt <= 5; attempt++) {
    final String? token;
    try {
      token = await readToken();
    } catch (e) {
      print('[PUSH] Token read failed at attempt $attempt: $e');
      if (attempt == 5) {
        throw PushNotificationSetupException(
          'Token notifiche non creato dal browser. Su iPhone verifica che l\'app sia installata nella schermata Home e che le notifiche non siano bloccate.',
          e,
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
      continue;
    }
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
  final deviceId = await getPushDeviceId();
  final payload = jsonEncode({
    'action': 'registerPushToken',
    'userId': userId,
    'token': token,
    'deviceId': deviceId,
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
    throw PushNotificationSetupException(
      'Token creato, ma non salvato sul server. Riprova tra poco.',
      'HTTP ${res.statusCode}: ${res.body}',
    );
  }
}

Future<PushSendResult> _sendPushTestToBackend(
    String userId, String token) async {
  final sessionToken = globalSessionToken;
  if (sessionToken == null || sessionToken.isEmpty) {
    throw const PushNotificationSetupException(
      'Sessione scaduta: effettua nuovamente il login.',
    );
  }
  final payload = jsonEncode({
    'action': 'sendTestPushToken',
    'userId': userId,
    'token': token,
    'deviceId': await getPushDeviceId(),
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
    throw PushNotificationSetupException(
      'Test notifiche non inviato dal server.',
      'HTTP ${res.statusCode}: ${res.body}',
    );
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return PushSendResult.fromJson(data);
}
