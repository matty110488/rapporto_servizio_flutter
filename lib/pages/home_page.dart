import 'package:flutter/material.dart';

import '../screens/archivio_screen.dart';
import 'designazioni_page.dart';
import 'gare_page.dart';
import 'root_screen.dart';

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
        label: 'Rapporti di Servizio',
        subtitle: 'Compila e invia il rapportino gara',
        onTap: () => _openPage(context, RootScreen(loggedUser: loggedUser)),
      ),
      _HomeNavData(
        icon: Icons.assignment_turned_in,
        label: 'Le tue designazioni',
        subtitle: 'Vedi servizi assegnati e conclusi',
        onTap: () => _openPage(
          context,
          DesignazioniPage(loggedUser: loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.folder,
        label: 'Rapportini completati',
        subtitle: 'Apri e modifica rapportini gia inviati',
        onTap: () => _openPage(
          context,
          ArchivioScreen(loggedUser: loggedUser),
        ),
      ),
      _HomeNavData(
        icon: Icons.flag,
        label: 'Calendario gare',
        subtitle: 'Consulta eventi e disponibilita',
        onTap: () => _openPage(context, GarePage(loggedUser: loggedUser)),
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF7FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(userName),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    itemCount: navItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      return _HomeCard(
                        icon: item.icon,
                        label: item.label,
                        subtitle: item.subtitle,
                        onTap: item.onTap,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A66C2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004E9A), Color(0xFF0A66C2), Color(0xFF338FE5)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A66C2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Benvenuto',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          //  const SizedBox(height: 8),
          //  const Text(
          //    'Scegli un\'area per iniziare rapidamente.',
          //    style: TextStyle(color: Colors.white),
          //  ),
        ],
      ),
    );
  }
}

class _HomeNavData {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  _HomeNavData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE8F6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0A66C2)),
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2B40),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF49627E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
