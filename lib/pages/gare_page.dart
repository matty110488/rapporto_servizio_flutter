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

  @override
  void initState() {
    super.initState();

    notion = NotionService(
      apiKey: "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",
      databaseId: "2acde089ef958065aa24fce00357a425",
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
    if (_isStatusBloccato(gara.status)) {
      return _isUserAssigned(gara);
    }

    final start = DateTime.tryParse(gara.dataGara);
    if (start == null) return true;

    final limite = start.subtract(const Duration(days: 2));
    final now = DateTime.now();

    if (now.isAfter(limite)) {
      return _isUserAssigned(gara);
    }
    return true;
  }

  bool _isStatusBloccato(String status) {
    final upper = status.toUpperCase();
    return upper == 'GARA COPERTA' || upper == 'ANNULLATA';
  }

  Map<String, List<Gara>> _garePerMese() {
    final sorted = List<Gara>.from(gare)
      ..sort(
          (a, b) => a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase()));

    final Map<String, List<Gara>> grouped = {};
    for (final gara in sorted) {
      final date = DateTime.tryParse(gara.dataGara);
      final label = date == null ? 'Senza data' : _meseAnno(date);
      grouped.putIfAbsent(label, () => []).add(gara);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final daA = DateTime.tryParse(a.value.first.dataGara);
        final daB = DateTime.tryParse(b.value.first.dataGara);
        if (daA != null && daB != null) return daA.compareTo(daB);
        return a.key.compareTo(b.key);
      });

    return {for (final e in sortedEntries) e.key: e.value};
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...entry.value.map((g) {
                        final showAction = _loggedUserId != null &&
                            !_isStatusBloccato(g.status);

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
                                if (g.status.isNotEmpty)
                                  Text("Status: ${g.status}"),
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
                      }),
                    ],
                  ),
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
}
