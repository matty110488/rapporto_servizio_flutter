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
  String dsc = '';
  bool loading = true;
  String? errorMessage;

  late NotionService notion;

  @override
  void initState() {
    super.initState();
    notion = NotionService(
      apiKey: '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',
      databaseId: '2acde089ef958065aa24fce00357a425',
    );
    loadPeople();
  }

  Future<void> loadPeople() async {
    try {
      final kronosNames = await _fetchNames(widget.gara.kronosIds);
      final pcNames = await _fetchNames(widget.gara.pcSegreteriaIds);
      final dscName = widget.gara.dscIds.isNotEmpty
          ? await notion.fetchNameFromPage(widget.gara.dscIds.first)
          : '';

      if (!mounted) return;
      setState(() {
        kronos = kronosNames;
        pcSegreteria = pcNames;
        dsc = dscName;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Impossibile caricare i nominativi: $e';
      });
    }
  }

  Future<List<String>> _fetchNames(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map(notion.fetchNameFromPage).toList();
    final names = await Future.wait(futures, eagerError: true);
    return names.where((name) => name.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.gara.titolo)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.gara.titolo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Data: ${widget.gara.dataGara}'),
          Text('Località: ${widget.gara.localita} - '
              '${widget.gara.sitoGara}'),
          const SizedBox(height: 12),
          Text(
            'DSC: ${dsc.isEmpty ? 'Non assegnato' : dsc}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildListSection('Kronos designati', kronos),
          const SizedBox(height: 12),
          _buildListSection('PC Segreteria', pcSegreteria),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> values) {
    if (values.isEmpty) {
      return Text('$title: nessun nominativo');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...values.map((value) => Text('- $value')),
      ],
    );
  }
}
