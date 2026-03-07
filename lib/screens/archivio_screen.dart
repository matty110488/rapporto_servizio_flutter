import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../pages/root_screen.dart';
import '../services/notion_service.dart';
import '../widgets/help_dialog.dart';

class ArchivioScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const ArchivioScreen({super.key, required this.loggedUser});

  @override
  State<ArchivioScreen> createState() => _ArchivioScreenState();
}

class _ArchivioScreenState extends State<ArchivioScreen> {
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';
  late NotionService notion;
  List<Gara> gareCompletate = [];
  bool loading = true;
  String? errore;

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      apiKey: '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',
      databaseId: _db2025,
    );
    _caricaArchivio();
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool get _isAdmin {
    final props = widget.loggedUser['properties'];
    if (props is! Map<String, dynamic>) return false;

    const adminKeys = [
      'ADMIN',
      'Admin',
      'admin',
      'RUOLO',
      'Ruolo',
      'ROLE',
      'Role',
      'role',
    ];

    bool matchAdminText(String? value) {
      if (value == null) return false;
      final lower = value.toLowerCase();
      return lower == 'admin' || lower == 'amministratore';
    }

    bool hasAdminValue(Map<String, dynamic> field) {
      if (field['checkbox'] == true) return true;

      final select = field['select'];
      if (select is Map<String, dynamic>) {
        final name = select['name'];
        if (name is String && matchAdminText(name)) return true;
      }

      final multi = field['multi_select'];
      if (multi is List) {
        for (final entry in multi) {
          if (entry is Map<String, dynamic>) {
            final name = entry['name'];
            if (name is String && matchAdminText(name)) {
              return true;
            }
          }
        }
      }

      final rich = field['rich_text'];
      if (rich is List && rich.isNotEmpty) {
        final first = rich.first;
        if (first is Map<String, dynamic>) {
          final text = first['plain_text'];
          if (text is String && matchAdminText(text)) {
            return true;
          }
        }
      }

      return false;
    }

    for (final key in adminKeys) {
      final value = props[key];
      if (value is Map<String, dynamic> && hasAdminValue(value)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _caricaArchivio() async {
    setState(() {
      loading = true;
      errore = null;
    });

    try {
      final results = await notion.fetchGare(
        additionalDatabaseIds: const [_db2026],
      );
      final all = results.map((e) => Gara.fromNotion(e)).toList();

      const statiCompletati = {'RAPPORTINO RICEVUTO', 'RAPPORTINO INVIATO'};
      final userId = _loggedUserId;

      final filtered = all.where((g) {
        final isCompleted = statiCompletati.contains(g.status.trim().toUpperCase());
        if (!isCompleted) return false;
        if (_isAdmin) return true;
        if (userId == null) return false;
        return g.dscIds.contains(userId);
      }).toList();

      filtered.sort((a, b) {
        final da = DateTime.tryParse(a.dataGara);
        final db = DateTime.tryParse(b.dataGara);
        if (da != null && db != null) return db.compareTo(da);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        gareCompletate = filtered;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errore = e.toString();
        loading = false;
      });
    }
  }

  String _fmtDateRange(Gara g) {
    String fmt(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso.isEmpty ? '-' : iso;
      return DateFormat('dd/MM/yyyy').format(d);
    }

    final start = fmt(g.dataGara);
    final end = g.dataGaraFine.isNotEmpty ? fmt(g.dataGaraFine) : start;
    return start == end ? start : '$start - $end';
  }

  void _apriModifica(Gara gara) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RootScreen(
          loggedUser: widget.loggedUser,
          initialGaraId: gara.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapportini completati'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Archivio',
              HelpContent.archivio,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aggiorna',
            onPressed: _caricaArchivio,
          ),
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errore != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Errore nel caricamento: $errore'),
                  ),
                )
              : gareCompletate.isEmpty
                  ? const Center(
                      child: Text('Nessuna gara con rapportino completato.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: gareCompletate.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final gara = gareCompletate[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE8F6)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gara.titolo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Data: ${_fmtDateRange(gara)}'),
                                if (gara.localita.isNotEmpty)
                                  Text('Luogo: ${gara.localita}'),
                                if (gara.sport.isNotEmpty)
                                  Text('Sport: ${gara.sport}'),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: () => _apriModifica(gara),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Modifica rapportino'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
