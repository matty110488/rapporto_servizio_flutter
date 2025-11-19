import 'package:flutter/material.dart';
import '../services/notion_service.dart';
import '../models/gara.dart';
import 'dettaglio_gara.dart';

class GarePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  const GarePage({super.key, required this.loggedUser});

  @override
  State<GarePage> createState() => _GarePageState();
}

class _GarePageState extends State<GarePage> {
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
      databaseId: "2afde089ef9580e2b0e7d19d44f3a3f6",
    );

    load();
  }

  Future<void> load({bool showSpinner = false}) async {
    if (showSpinner) {
      setState(() {
        loading = true;
      });
    }
    final results = await notion.fetchGare();

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
        title: Text("Gare 2025"),
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

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(g.titolo),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${g.dataGara} - ${g.localita}"),
                            if (g.sport.isNotEmpty) Text(g.sport),
                            if (g.status.isNotEmpty) Text("Status: ${g.status}"),
                            if (showAction)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Builder(
                                    builder: (context) {
                                      final candidabile = _puoCandidarsi(g);
                                      return ElevatedButton(
                                        onPressed: !candidabile ||
                                                updatingGare.contains(g.id)
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
                                                : candidabile
                                                    ? "Mi rendo disponibile"
                                                    : "Designazione chiusa"),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DettaglioGara(gara: g),
                            ),
                          );
                        },
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
}
