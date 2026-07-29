import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_environment.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/push_notification_service.dart';
import 'state/session_state.dart';
import 'theme/app_theme.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    await initFirebaseMessaging();
  }

  runApp(CronoValtellinesiApp());
}

class CronoValtellinesiApp extends StatefulWidget {
  const CronoValtellinesiApp({super.key});

  @override
  State<CronoValtellinesiApp> createState() => _CronoValtellinesiAppState();
}

class _CronoValtellinesiAppState extends State<CronoValtellinesiApp> {
  Map<String, dynamic>? loggedUser;
  bool restoringSession = true;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get _supportsPush {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _registerPushTokenForUser(Map<String, dynamic> user) async {
    if (!_supportsPush) return;
    if (!await pushNotificationsAppEnabled()) return;

    final userId = user['id'];
    if (userId is! String || userId.isEmpty) return;

    try {
      final token = await getCurrentPushToken();
      if (token != null && token.isNotEmpty) {
        await sendTokenToBackend(userId, token);
        print('[PUSH] Token saved to backend for user $userId');
      } else {
        print('[PUSH] Token unavailable for user $userId');
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final currentUserId = loggedUser?['id'];
        final stillEnabled = await pushNotificationsAppEnabled();
        if (newToken.isNotEmpty &&
            currentUserId == userId &&
            globalSessionToken != null &&
            stillEnabled) {
          await sendTokenToBackend(userId, newToken);
          print('[PUSH] Refreshed token saved for user $userId');
        } else {
          print('[PUSH] Refreshed token ignored: no active opted-in user.');
        }
      });
    } catch (e) {
      print('Push token registration failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('logged_user');

    Map<String, dynamic>? user;

    if (stored != null) {
      final decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        user = decoded;
      } else if (decoded is Map) {
        user = Map<String, dynamic>.from(decoded);
      }
    }

    final restoredToken = user?['_sessionToken'];
    if (restoredToken is! String || restoredToken.isEmpty) {
      user = null;
      await prefs.remove('logged_user');
    }

    if (!mounted) return;

    setState(() {
      loggedUser = user;
      restoringSession = false;
    });
    globalLoggedUserId = user?['id'];
    globalSessionToken = user?['_sessionToken'];
    if (user != null) {
      await _registerPushTokenForUser(user);
    } else if (_supportsPush) {
      // Ripulisce anche le installazioni rimaste sloggate con una versione
      // precedente, che non revocava il token Firebase durante il logout.
      await revokePushTokenLocally();
    }
  }

  Future<void> _handleLogin(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', jsonEncode(user));

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
    globalLoggedUserId = user['id'];
    globalSessionToken = user['_sessionToken'];
    await _registerPushTokenForUser(user);
  }

  Future<void> _handleLogout() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    final userId = loggedUser?['id'];
    if (_supportsPush && userId is String && userId.isNotEmpty) {
      try {
        await disableNotificationsForUser(userId);
      } catch (error) {
        // Il logout prosegue: la funzione revoca comunque il token locale.
        print('[PUSH] Server cleanup during logout failed: $error');
      }
    }

    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');

    if (!mounted) return;

    setState(() {
      loggedUser = null;
    });
    globalLoggedUserId = null;
    globalSessionToken = null;
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  Widget _environmentBanner(BuildContext context, Widget? child) {
    final app = child ?? const SizedBox.shrink();
    if (!isTestEnvironment) return app;

    return Banner(
      message: 'TEST',
      location: BannerLocation.topEnd,
      color: Colors.deepOrange,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      child: app,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppVisualStyle>(
      valueListenable: AppThemeController.style,
      builder: (context, style, _) {
        final Widget home;
        if (restoringSession) {
          home = const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (loggedUser == null) {
          home = LoginPage(onLogin: _handleLogin);
        } else {
          home = HomePage(
            loggedUser: loggedUser!,
            onLogout: _handleLogout,
          );
        }

        return MaterialApp(
          title: appDisplayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(style),
          builder: _environmentBanner,
          home: home,
        );
      },
    );
  }
}
