import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/push_notification_service.dart';
import 'state/session_state.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await initFirebaseMessaging();
  }

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

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && globalLoggedUserId != null) {
        sendTokenToBackend(globalLoggedUserId!, token);
      }
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

  ThemeData _buildPremiumTheme() {
    const primary = Color(0xFF0A66C2); // blu elegante
    const textColor = Color(0xFF1C1C1E); // nero soft
    const lightGray = Color(0xFFF2F2F7); // grigio Apple

    final base = ThemeData.light();

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: const Color.fromARGB(255, 179, 209, 241),
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: primary,
        background: Colors.white,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.8,
        shadowColor: Colors.black12,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
        fontFamily: 'Roboto',
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: primary,
        size: 28,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightGray,
        labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildPremiumTheme();

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
