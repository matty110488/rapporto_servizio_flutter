import 'package:flutter/material.dart';
import 'widgets/header.dart';
import 'widgets/gara_form.dart';
import 'widgets/cronometristi_form.dart';
import 'widgets/apparecchiatura_form.dart';
import 'widgets/danni_form.dart';
import 'pdf/generatore_pdf2.dart';
import 'package:share_plus/share_plus.dart';
import 'screens/archivio_screen.dart';
import 'widgets/allegati_form.dart';
import 'pages/gare_page.dart';

void main() {
  runApp(RapportoServizioApp());
}

class RapportoServizioApp extends StatelessWidget {
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
    return MaterialApp(
      title: 'Rapporto di Servizio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: theme,
      darkTheme: theme,
      home: RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int selectedIndex = 0;

  final garaKey = GlobalKey<GaraFormState>();
  final cronometristiKey = GlobalKey<CronometristiFormState>();
  final apparecchiaturaKey = GlobalKey<ApparecchiaturaFormState>();
  final danniKey = GlobalKey<DanniFormState>();
  final allegatiKey = GlobalKey<AllegatiFormState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      Scaffold(
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
                    final cronos =
                        cronometristiKey.currentState?.getData() ?? [];
                    final app =
                        apparecchiaturaKey.currentState?.getData() ?? [];
                    final danni = danniKey.currentState?.getData() ?? '';
                    final immagini =
                        allegatiKey.currentState?.getImages() ?? [];

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
      ),
      ArchivioScreen(),
      const GarePage(),
    ];

    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Rapporto'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Archivio'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Gare'),
        ],
      ),
    );
  }
}
