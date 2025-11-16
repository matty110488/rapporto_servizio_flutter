import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/push_notification_service.dart';
import 'state/session_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await initFirebaseMessaging();

  runApp(CronoValtellinesiApp());
}

class CronoValtellinesiApp extends StatefulWidget {
  @override
  State<CronoValtellinesiApp> createState() => _CronoValtellinesiAppState();
}

class _CronoValtellinesiAppState extends State<CronoValtellinesiApp> {
  Map<String, dynamic>? loggedUser;
  bool restoringSession = true;

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

    if (!mounted) return;

    setState(() {
      loggedUser = user;
      restoringSession = false;
    });
    globalLoggedUserId = user?['id'];
  }

  Future<void> _handleLogin(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', jsonEncode(user));

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
    globalLoggedUserId = user['id'];

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && globalLoggedUserId != null) {
      sendTokenToBackend(globalLoggedUserId!, token);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');

    if (!mounted) return;

    setState(() {
      loggedUser = null;
    });
    globalLoggedUserId = null;
  }

  ThemeData _buildWhiteBlueTheme() {
    final base = ThemeData.light();
    final colorScheme = base.colorScheme.copyWith(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      background: Colors.white,
      surface: Colors.white,
    );

    return base.copyWith(
      primaryColor: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      colorScheme: colorScheme,
      textTheme: base.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: Colors.black),
        ),
      ),
      iconTheme: base.iconTheme.copyWith(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildWhiteBlueTheme();

    if (restoringSession) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (loggedUser == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: LoginPage(onLogin: _handleLogin),
      );
    }

    return MaterialApp(
      title: 'Crono Valtellinesi',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: HomePage(
        loggedUser: loggedUser!,
        onLogout: _handleLogout,
      ),
    );
  }
}
