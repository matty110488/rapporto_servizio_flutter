import 'package:flutter/material.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';

class DettaglioGara extends StatefulWidget {
  final Gara gara;

  const DettaglioGara({super.key, required this.gara});

  @override
  State<DettaglioGara> createState() => _DettaglioGaraState();
}

class _DettaglioGaraState extends State<DettaglioGara> {
  List<String> kronos = [];
  List<String> pcSegreteria = [];
  String dsc = "";
  bool loading = true;

  late NotionService notion;

  @override
  void initState() {
    super.initState();

    notion = NotionService(
      apiKey: "SECRET_API_KEY",
      databaseId: "2acde089ef958065aa24fce00357a425",
    );

    loadPeople();
  }

  Future<void> loadPeople() async {
    // Kronos
    for (final id in widget.gara.kronosIds) {
      final name = await notion.fetchNameFromPage(id);
      kronos.add(name);
    }

    // DSC
    if (widget.gara.dscIds.isNotEmpty) {
      dsc = await notion.fetchNameFromPage(widget.gara.dscIds.first);
    }

    // PC segreteria
    for (final id in widget.gara.pcSegreteriaIds) {
      final name = await notion.fetchNameFromPage(id);
      pcSegreteria.add(name);
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return Scaffold(
        appBar: AppBar(title: Text(widget.gara.titolo)),
        body: Center(child: CircularProgressIndicator()),
      );

    return Scaffold(
      appBar: AppBar(title: Text(widget.gara.titolo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Data: ${widget.gara.dataGara}"),
          Text("Luogo: ${widget.gara.localita}"),
          Divider(),
          Text("DSC: $dsc", style: TextStyle(fontWeight: FontWeight.bold)),
          Divider(),
          Text("Kronos designati:"),
          for (final k in kronos) Text("• $k"),
          Divider(),
          Text("PC Segreteria:"),
          for (final p in pcSegreteria) Text("• $p"),
        ],
      ),
    );
  }
}
