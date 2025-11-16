import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../state/session_state.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  final token = await messaging.getToken();
  print("FCM TOKEN: $token");
  final userId = globalLoggedUserId;
  if (token != null && userId != null) {
    await sendTokenToBackend(userId, token);
  }

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notif = message.notification;
    if (notif != null) {
      flutterLocalNotificationsPlugin.show(
        0,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Notifiche',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("Notifica aperta: ${message.notification?.title}");
  });
}

Future<void> sendTokenToBackend(String userId, String token) async {
  final url = Uri.parse("http://192.168.1.21:3000/save-token");

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": userId,
        "fcmToken": token,
      }),
    );

    print("Token inviato per $userId (status ${response.statusCode})");
  } catch (e) {
    print("Errore invio token al backend: $e");
  }
}
