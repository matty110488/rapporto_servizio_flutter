import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/help_content.dart';
import '../services/notion_service.dart';
import '../models/gara.dart';
import '../widgets/help_dialog.dart';
import 'dettaglio_gara.dart';

class GarePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  const GarePage({super.key, required this.loggedUser});

  @override
  State<GarePage> createState() => _GarePageState();
}

class _GarePageState extends State<GarePage> {
  static const _db2025 = "2afde089ef9580e2b0e7d19d44f3a3f6";
  static const _db2026 = "2b1de089ef9580729622ff9543046cbc";

  late NotionService notion;
  List<Gara> gare = [];
  bool loading = true;
  Set<String> updatingGare = {};
  Set<String> expandedMonths = {};

  @override
  void initState() {
    super.initState();

    notion = NotionService(
      apiKey: "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",
      databaseId: _db2025,
    );

    load();
  }

  Future<void> load({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() {
        loading = true;
      });
    }
    final results = await notion.fetchGare(
      additionalDatabaseIds: const [_db2026],
    );

    if (!mounted) return;
    setState(() {
      gare = results.map((e) => Gara.fromNotion(e)).toList();
      loading = false;
    });
  }

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool _isUserAssigned(Gara gara) {
    final userId = _loggedUserId;
    if (userId == null) return false;
    return gara.kronosIds.contains(userId);
  }

  bool _puoCandidarsi(Gara gara) {
    final upper = gara.status.toUpperCase();
    return upper == 'DA GESTIRE' || upper == 'IN PROGRESS';
  }

  Map<String, List<Gara>> _garePerMese() {
    final sorted = List<Gara>.from(gare)
      ..sort((a, b) {
        final da = _parseDate(a.dataGara);
        final db = _parseDate(b.dataGara);

        if (da != null && db != null) {
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
        } else if (da != null && db == null) {
          return -1; // gare con data prima di quelle senza data
        } else if (da == null && db != null) {
          return 1;
        }

        return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
      });

    final Map<String, List<Gara>> grouped = {};
    for (final gara in sorted) {
      final date = _parseDate(gara.dataGara);
      final label = date == null ? 'Senza data' : _meseAnno(date);
      grouped.putIfAbsent(label, () => []).add(gara);
    }

    // La mappa mantiene l'ordine di inserimento, che segue ordinamento cronologico.
    return grouped;
  }

  Future<void> _toggleDisponibilita(Gara gara, bool join) async {
    final userId = _loggedUserId;
    if (userId == null) return;

    setState(() {
      updatingGare.add(gara.id);
    });

    final ids = List<String>.from(gara.kronosIds);
    if (join) {
      if (!ids.contains(userId)) ids.add(userId);
    } else {
      ids.removeWhere((id) => id == userId);
    }

    try {
      await notion.updateKronosDesignati(gara.id, ids);
      await load();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            join
                ? "Ti sei reso disponibile per ${gara.titolo}"
                : "Hai annullato la disponibilità per ${gara.titolo}",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante l'aggiornamento: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        updatingGare.remove(gara.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Calendario gare"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Aiuto',
            onPressed: () => showHelpDialog(
              context,
              'Calendario',
              HelpContent.calendario,
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
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: _garePerMese().entries.map((entry) {
                final isExpanded = expandedMonths.contains(entry.key);
                return ExpansionTile(
                  key: PageStorageKey(entry.key),
                  initiallyExpanded: isExpanded,
                  title: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onExpansionChanged: (open) {
                    setState(() {
                      if (open) {
                        expandedMonths.add(entry.key);
                      } else {
                        expandedMonths.remove(entry.key);
                      }
                    });
                  },
                  children: entry.value.map((g) {
                    final showAction = _loggedUserId != null;
                    final candidabile = _puoCandidarsi(g);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
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
                                  if (g.status.isNotEmpty) _statusChip(g.status),
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
                              if (showAction && candidabile) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Builder(
                                    builder: (context) {
                                      return ElevatedButton(
                                        onPressed: updatingGare.contains(g.id)
                                            ? null
                                            : () => _toggleDisponibilita(
                                                  g,
                                                  !_isUserAssigned(g),
                                                ),
                                        child: updatingGare.contains(g.id)
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(_isUserAssigned(g)
                                                ? "Rimuovimi dalla gara"
                                                : "Mi rendo disponibile"),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }

  String _meseAnno(DateTime date) {
    const mesi = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    final nome = mesi[date.month - 1];
    return '$nome ${date.year}';
  }

  DateTime? _parseDate(String value) => DateTime.tryParse(value);

  String _formatDateRange(Gara gara) {
    final start = _fmtDate(gara.dataGara);
    final end = gara.dataGaraFine.isNotEmpty ? _fmtDate(gara.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start - $end';
    return start ?? end ?? '-';
  }

  String? _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  Widget _statusChip(String status) {
    final upper = status.trim().toUpperCase();
    Color bg;
    Color fg;
    if (upper == 'DESIGNAZIONE INVIATA') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else if (upper == 'GARA COMPLETATA' || upper == 'SICWIN OK') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
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
}
