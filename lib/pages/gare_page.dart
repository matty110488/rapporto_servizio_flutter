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
          : ListView.builder(
              itemCount: gare.length,
              itemBuilder: (_, i) {
                final g = gare[i];

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(g.titolo),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${g.dataGara} - ${g.localita}"),
                        if (g.sport.isNotEmpty) Text("Sport: ${g.sport}"),
                        if (g.sitoGara.isNotEmpty) Text("Sito: ${g.sitoGara}"),
                        if (g.organizzatore.isNotEmpty)
                          Text("Organizzatore: ${g.organizzatore}"),
                        if (_loggedUserId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ElevatedButton(
                                onPressed: updatingGare.contains(g.id)
                                    ? null
                                    : () => _toggleDisponibilita(
                                          g,
                                          !_isUserAssigned(g),
                                        ),
                                child: updatingGare.contains(g.id)
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_isUserAssigned(g)
                                        ? "Rimuovimi dalla gara"
                                        : "Mi rendo disponibile"),
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
              },
            ),
    );
  }
}
