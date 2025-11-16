import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'models/gara.dart';
import 'services/notion_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:http/http.dart' as http;

// ------------------------------------------------------------
//  NOTIFICHE
// ------------------------------------------------------------

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await _initFirebaseMessaging();

  runApp(CronoValtellinesiApp());
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

    print("📡 Token inviato per $userId (status ${response.statusCode})");
  } catch (e) {
    print("❌ Errore invio token al backend: $e");
  }
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // Permessi Android 13+ e iOS
  await messaging.requestPermission();

  // Token dispositivo
  final token = await messaging.getToken();
  print("FCM TOKEN: $token");
  if (token != null && globalLoggedUserId != null) {
    await sendTokenToBackend(globalLoggedUserId!, token);
  }

  // Inizializzazione notifiche locali
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Notifiche in foreground
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

  // Notifica cliccata quando l'app e chiusa
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("Notifica aperta: ${message.notification?.title}");
  });
}

// ------------------------------------------------------------
//  APP ROOT
// ------------------------------------------------------------

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
  }

  Future<void> _handleLogin(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_user', jsonEncode(user));

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
    globalLoggedUserId = user['id'];

// 👉 ottieni di nuovo il token e invialo ORA al backend
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
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

// ------------------------------------------------------------
//  ROOT SCREEN (rapportino) – TUTTO IL TUO CODICE ORIGINALE
// ------------------------------------------------------------

class RootScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const RootScreen({super.key, required this.loggedUser});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final garaKey = GlobalKey<GaraFormState>();
  final cronometristiKey = GlobalKey<CronometristiFormState>();
  final apparecchiaturaKey = GlobalKey<ApparecchiaturaFormState>();
  final danniKey = GlobalKey<DanniFormState>();
  final allegatiKey = GlobalKey<AllegatiFormState>();

  late NotionService notion;
  List<Gara> gareDisponibili = [];
  bool loadingGareList = true;
  String? gareError;
  Gara? selectedGara;
  int formVersion = 0;
  bool prefilling = false;
  int _prefillTicket = 0;

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      apiKey: "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",
      databaseId: "2acde089ef958065aa24fce00357a425",
    );
    _loadGareDsc();
  }

  Future<void> _loadGareDsc() async {
    setState(() {
      loadingGareList = true;
      gareError = null;
    });
    try {
      final results = await notion.fetchGare();
      final allGare =
          results.map((e) => Gara.fromNotion(e)).toList(growable: false);
      final userId = _loggedUserId;
      final filtered = userId == null
          ? <Gara>[]
          : allGare.where((g) => g.dscIds.contains(userId)).toList();

      final previousId = selectedGara?.id;
      Gara? nextSelection;
      if (previousId != null) {
        for (final gara in filtered) {
          if (gara.id == previousId) {
            nextSelection = gara;
            break;
          }
        }
      }
      nextSelection ??= filtered.length == 1 ? filtered.first : null;
      final selectionChanged = (previousId ?? '') != (nextSelection?.id ?? '');

      if (!mounted) return;
      setState(() {
        gareDisponibili = filtered;
        loadingGareList = false;
        selectedGara = nextSelection;
        if (selectionChanged) {
          formVersion++;
        }
      });
      if (nextSelection != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _prefillFromSelectedGara();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        gareError = e.toString();
        loadingGareList = false;
      });
    }
  }

  void _selectGara(Gara gara) {
    setState(() {
      selectedGara = gara;
      formVersion++;
    });
    _prefillFromSelectedGara();
  }

  Future<String?> _resolveName(String id) async {
    try {
      final name = await notion.fetchNameFromPage(id);
      if (name.isEmpty) return null;
      return name;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _resolveNames(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = await Future.wait(ids.map(_resolveName));
    return results.whereType<String>().toList();
  }

  Future<void> _prefillFromSelectedGara() async {
    final gara = selectedGara;
    if (gara == null) return;
    final ticket = ++_prefillTicket;
    setState(() {
      prefilling = true;
    });
    try {
      String? dscName;
      if (gara.dscIds.isNotEmpty) {
        dscName = await _resolveName(gara.dscIds.first);
      }
      final kronosNames = await _resolveNames(gara.kronosIds);

      if (!mounted || ticket != _prefillTicket) return;
      garaKey.currentState?.applyNotionData(
        nome: gara.titolo,
        organizzatore: gara.organizzatore,
        sportValue: gara.sport,
        luogo: gara.localita,
        dataInizio: gara.dataGara,
        dataFine:
            gara.dataGaraFine.isNotEmpty ? gara.dataGaraFine : gara.dataGara,
        dsc: dscName,
      );
      await Future<void>.microtask(() {});
      if (!mounted || ticket != _prefillTicket) return;
      cronometristiKey.currentState?.setCronometristi(kronosNames);
    } catch (e) {
      if (!mounted || ticket != _prefillTicket) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel precompilare la gara: $e')),
      );
    } finally {
      if (!mounted || ticket != _prefillTicket) return;
      setState(() {
        prefilling = false;
      });
    }
  }

  String _formatDateLabel(String value) {
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _garaDisplayLabel(Gara gara) {
    final start = _formatDateLabel(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty
        ? _formatDateLabel(gara.dataGaraFine)
        : start;
    final dateLabel = (end != start) ? "$start → $end" : start;
    final luogo = gara.localita.isEmpty ? '-' : gara.localita;
    return "$dateLabel · ${gara.titolo} · $luogo";
  }

  String _garaDateRange(Gara gara) {
    final start = _formatDateLabel(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty
        ? _formatDateLabel(gara.dataGaraFine)
        : start;
    return end != start ? "$start → $end" : start;
  }

  Widget _buildGareSelectionCard() {
    if (loadingGareList) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Expanded(child: Text("Carico le gare in cui sei DSC...")),
            ],
          ),
        ),
      );
    }

    if (gareError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Impossibile recuperare le gare",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(gareError!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loadGareDsc,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (gareDisponibili.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Non risultano gare in cui risulti DSC. Contatta la segreteria per abilitare il rapportino.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Seleziona la gara per cui vuoi compilare il rapportino",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: gareDisponibili.any((g) => g.id == selectedGara?.id)
                  ? selectedGara?.id
                  : null,
              items: gareDisponibili
                  .map(
                    (gara) => DropdownMenuItem<String>(
                      value: gara.id,
                      child: Text(
                        _garaDisplayLabel(gara),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final gara = gareDisponibili.firstWhere((g) => g.id == value);
                _selectGara(gara);
              },
              decoration: const InputDecoration(
                labelText: 'Gara',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              hint: const Text('Seleziona una gara'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedGaraInfo() {
    final gara = selectedGara;
    if (gara == null) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_available),
        title: Text(gara.titolo),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: ${_garaDateRange(gara)}"),
            Text("Luogo: ${gara.localita.isEmpty ? '-' : gara.localita}"),
            if (gara.organizzatore.isNotEmpty)
              Text("Organizzatore: ${gara.organizzatore}"),
            if (gara.sport.isNotEmpty) Text("Sport: ${gara.sport}"),
          ],
        ),
      ),
    );
  }

  Widget _buildRapportoForm() {
    return Column(
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
            final garaSelezionata = selectedGara;
            if (garaSelezionata == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Seleziona prima una gara in cui sei DSC'),
                ),
              );
              return;
            }

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
              'garaSelezionata': {
                'id': garaSelezionata.id,
                'titolo': garaSelezionata.titolo,
                'data': garaSelezionata.dataGara,
                'dataFine': garaSelezionata.dataGaraFine,
                'luogo': garaSelezionata.localita,
              },
            }, salvaLocalmente: true);
            await Share.shareXFiles([XFile(file.path)], text: 'Rapporto PDF');
          },
          icon: Icon(Icons.picture_as_pdf),
          label: Text("Genera e invia PDF"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canFillForm = selectedGara != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Crono Valtellinesi'),
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
              _buildGareSelectionCard(),
              const SizedBox(height: 16),
              _buildSelectedGaraInfo(),
              if (prefilling)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (!canFillForm &&
                  !loadingGareList &&
                  gareDisponibili.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Seleziona una gara per abilitare il rapportino.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              IgnorePointer(
                ignoring: !canFillForm,
                child: Opacity(
                  opacity: canFillForm ? 1 : 0.35,
                  child: KeyedSubtree(
                    key: ValueKey(formVersion),
                    child: _buildRapportoForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
//  HOME PAGE
// ------------------------------------------------------------

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
        label: 'Rapportini',
        onTap: () => _openPage(
          context,
          RootScreen(loggedUser: loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.folder,
        label: 'Archivio rapportini',
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

// ------------------------------------------------------------
//  HOME CARD
// ------------------------------------------------------------

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

String? globalLoggedUserId;
