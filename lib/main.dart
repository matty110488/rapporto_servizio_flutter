import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/header.dart';
import 'widgets/gara_form.dart';
import 'widgets/cronometristi_form.dart';
import 'widgets/apparecchiatura_form.dart';
import 'widgets/danni_form.dart';
import 'widgets/allegati_form.dart';

import 'pdf/generatore_pdf2.dart';
import 'package:share_plus/share_plus.dart';

import 'screens/archivio_screen.dart';
import 'pages/gare_page.dart';
import 'pages/login_page.dart';

void main() {
  runApp(RapportoServizioApp());
}

class RapportoServizioApp extends StatefulWidget {
  @override
  State<RapportoServizioApp> createState() => _RapportoServizioAppState();
}

class _RapportoServizioAppState extends State<RapportoServizioApp> {
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
        user = Map<String, dynamic>.from(decoded as Map);
      }
    }
    if (!mounted) return;
    setState(() {
      loggedUser = user;
      restoringSession = false;
    });
  }

  Future<void> _handleLogin(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', jsonEncode(user));
    if (!mounted) return;
    setState(() {
      loggedUser = user;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_user');
    if (!mounted) return;
    setState(() {
      loggedUser = null;
    });
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
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black.withOpacity(0.6),
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

    // 🔒 SE NON È LOGGATO → Mostra la schermata login
    if (loggedUser == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: LoginPage(
          onLogin: (user) {
            _handleLogin(user);
          },
        ),
      );
    }

    // 🔓 Se loggato → mostra la nuova home
    return MaterialApp(
      title: 'Rapporto di Servizio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: theme,
      darkTheme: theme,
      home: HomePage(
        loggedUser: loggedUser!,
        onLogout: _handleLogout,
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final garaKey = GlobalKey<GaraFormState>();
  final cronometristiKey = GlobalKey<CronometristiFormState>();
  final apparecchiaturaKey = GlobalKey<ApparecchiaturaFormState>();
  final danniKey = GlobalKey<DanniFormState>();
  final allegatiKey = GlobalKey<AllegatiFormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapporto'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Home'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderWidget(),
              SizedBox(height: 24),
              GaraForm(
                key: garaKey,
                onDateRangeChanged: (da, a) {
                  cronometristiKey.currentState?.syncDaysWithRange(da, a);
                },
              ),
              SizedBox(height: 24),
              CronometristiForm(key: cronometristiKey),
              SizedBox(height: 24),
              ApparecchiaturaForm(key: apparecchiaturaKey),
              SizedBox(height: 24),
              DanniForm(key: danniKey),
              AllegatiForm(key: allegatiKey),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final gara = garaKey.currentState?.getData() ?? {};
                  final cronos = cronometristiKey.currentState?.getData() ?? [];
                  final app = apparecchiaturaKey.currentState?.getData() ?? [];
                  final danni = danniKey.currentState?.getData() ?? '';
                  final immagini = allegatiKey.currentState?.getImages() ?? [];

                  final file = await generaPdfConDati({
                    'gara': gara,
                    'cronometristi': cronos,
                    'apparecchiature': app,
                    'danni': danni,
                    'allegati': immagini,
                  }, salvaLocalmente: true);
                  await Share.shareXFiles([XFile(file.path)],
                      text: 'Rapporto PDF');
                },
                icon: Icon(Icons.picture_as_pdf),
                label: Text("Genera e invia PDF"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.loggedUser,
    required this.onLogout,
  });

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _extractUserName() {
    final props = loggedUser['properties'];
    if (props is Map<String, dynamic>) {
      for (final entry in props.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          if (value['type'] == 'title') {
            final titles = value['title'] as List<dynamic>? ?? const [];
            if (titles.isNotEmpty) {
              final plain =
                  (titles.first as Map<String, dynamic>)['plain_text'];
              if (plain is String && plain.isNotEmpty) {
                return plain;
              }
            }
          }
          if (value['type'] == 'rich_text') {
            final texts = value['rich_text'] as List<dynamic>? ?? const [];
            if (texts.isNotEmpty) {
              final plain = (texts.first as Map<String, dynamic>)['plain_text'];
              if (plain is String && plain.isNotEmpty) {
                return plain;
              }
            }
          }
        }
      }
    }
    return 'Utente';
  }

  @override
  Widget build(BuildContext context) {
    final userName = _extractUserName();
    final navItems = [
      _HomeNavData(
        icon: Icons.assignment,
        label: 'Rapporto',
        onTap: () => _openPage(
          context,
          RootScreen(),
        ),
      ),
      _HomeNavData(
        icon: Icons.folder,
        label: 'Archivio',
        onTap: () => _openPage(context, ArchivioScreen()),
      ),
      _HomeNavData(
        icon: Icons.flag,
        label: 'Gare',
        onTap: () => _openPage(
          context,
          GarePage(loggedUser: loggedUser),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 170,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: SizedBox(
            width: 170,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        // title: Text('Benvenuto $userName'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ciao $userName',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            //  Text(
            //   'Seleziona una sezione',
            //    style: Theme.of(context).textTheme.titleMedium,
            //  ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: navItems
                    .map(
                      (item) => _HomeCard(
                        icon: item.icon,
                        label: item.label,
                        onTap: item.onTap,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeNavData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
