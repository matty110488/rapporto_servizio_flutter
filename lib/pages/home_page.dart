import 'package:flutter/material.dart';

import '../screens/archivio_screen.dart';
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
