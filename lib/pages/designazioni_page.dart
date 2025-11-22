import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../widgets/help_dialog.dart';
import 'dettaglio_gara.dart';

class DesignazioniPage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  const DesignazioniPage({super.key, required this.loggedUser});

  @override
  State<DesignazioniPage> createState() => _DesignazioniPageState();
}

class _DesignazioniPageState extends State<DesignazioniPage> {
  late NotionService notion;
  List<Gara> gareDaSvolgere = [];
  List<Gara> gareConcluse = [];
  bool loading = true;
  String? errore;

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
      databaseId: "2afde089ef9580e2b0e7d19d44f3a3f6",
    );
    _caricaGare();
  }

  Future<void> _caricaGare() async {
    setState(() {
      loading = true;
      errore = null;
    });
    try {
      final results = await notion.fetchGare();
      final all = results.map((e) => Gara.fromNotion(e)).toList();
      final userId = _loggedUserId;

      final allowedStatuses = {
        'DESIGNAZIONE INVIATA',
        'GARA COMPLETATA',
        'SICWIN OK',
      };

      final filtered = all.where((g) {
        if (userId == null) return false;
        final status = g.status.trim().toUpperCase();
        final statoValido = allowedStatuses.contains(status);
        final assegnato = g.kronosIds.contains(userId);
        return statoValido && assegnato;
      }).toList();

      final daSvolgere = <Gara>[];
      final concluse = <Gara>[];
      for (final g in filtered) {
        final status = g.status.trim().toUpperCase();
        if (status == 'GARA COMPLETATA' || status == 'SICWIN OK') {
          concluse.add(g);
        } else {
          daSvolgere.add(g);
        }
      }

      daSvolgere.sort(_compareGare);
      concluse.sort(_compareGare);

      if (!mounted) return;
      setState(() {
        gareDaSvolgere = daSvolgere;
        gareConcluse = concluse;
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

  DateTime? _parseDate(String value) => DateTime.tryParse(value);

  int _compareGare(Gara a, Gara b) {
    final da = _parseDate(a.dataGara);
    final db = _parseDate(b.dataGara);
    if (da != null && db != null) {
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
    } else if (da != null && db == null) {
      return -1;
    } else if (da == null && db != null) {
      return 1;
    }
    return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
  }

  Widget _buildSection(String title, List<Gara> items, String emptyText) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              Column(
                children: items
                    .map(
                      (g) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 1,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DettaglioGara(gara: g),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g.titolo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    _statusChip(g.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_formatDateRange(g)),
                                  ],
                                ),
                                if (g.localita.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.place, size: 16),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(g.localita)),
                                    ],
                                  ),
                                ],
                                if (g.sport.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.sports, size: 16),
                                      const SizedBox(width: 4),
                                      Flexible(child: Text(g.sport)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final upper = status.trim().toUpperCase();
    Color bg;
    Color fg;
    if (upper == 'DESIGNAZIONE INVIATA') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDateRange(Gara g) {
    final start = _fmtDate(g.dataGara);
    final end = g.dataGaraFine.isNotEmpty ? _fmtDate(g.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start - $end';
    return start ?? end ?? '-';
  }

  String? _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Designazioni'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Designazioni',
              HelpContent.designazioni,
            ),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Errore nel recupero delle designazioni',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(errore!),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _caricaGare,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  children: [
                    _buildSection(
                      'Servizi da svolgere',
                      gareDaSvolgere,
                      'Nessun servizio da svolgere.',
                    ),
                    _buildSection(
                      'Servizi conclusi',
                      gareConcluse,
                      'Nessun servizio concluso.',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
    );
  }
}
