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

  @override
  void initState() {
    super.initState();

    notion = NotionService(
      apiKey: "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",
      databaseId: "2acde089ef958065aa24fce00357a425",
    );

    load();
  }

  Future<void> load() async {
    final results = await notion.fetchGare();

    setState(() {
      gare = results.map((e) => Gara.fromNotion(e)).toList();
      loading = false;
    });
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
