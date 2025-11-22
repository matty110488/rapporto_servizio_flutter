import 'package:flutter/material.dart';

import '../constants/help_content.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  Widget _section(BuildContext context, String title, List<String> points) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...points.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(p)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aiuto'),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _section(context, 'Accesso', HelpContent.accesso),
            _section(context, 'Calendario', HelpContent.calendario),
            _section(context, 'Designazioni', HelpContent.designazioni),
            _section(context, 'Rapportini', HelpContent.rapportini),
            _section(context, 'Archivio', HelpContent.archivio),
            _section(context, 'Note utili', HelpContent.noteUtili),
          ],
        ),
      ),
    );
  }
}
