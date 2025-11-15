import 'package:flutter/material.dart';
import '../services/notion_service.dart';
import '../models/gara.dart';
import 'dettaglio_gara.dart';

class GarePage extends StatefulWidget {
  const GarePage({super.key});

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
      apiKey: "SECRET_API_KEY",
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
      appBar: AppBar(title: Text("Gare 2025")),
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
                    subtitle: Text("${g.dataGara} • ${g.localita}"),
                    trailing: Text(g.sport),
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
