import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      databaseId: '2afde089ef9580e2b0e7d19d44f3a3f6',
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.gara.titolo)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 10),
                  _buildPeopleCard(
                    title: 'DSC',
                    icon: Icons.badge,
                    values: dsc.isEmpty ? const [] : [dsc],
                    emptyText: 'Non assegnato',
                  ),
                  const SizedBox(height: 10),
                  _buildPeopleCard(
                    title: 'Kronos designati',
                    icon: Icons.groups,
                    values: kronos,
                    emptyText: 'Nessun nominativo',
                  ),
                  const SizedBox(height: 10),
                  _buildPeopleCard(
                    title: 'PC segreteria',
                    icon: Icons.computer,
                    values: pcSegreteria,
                    emptyText: 'Nessun nominativo',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    _buildErrorBox(errorMessage!),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.gara.titolo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(widget.gara.status),
            ],
          ),
          const SizedBox(height: 10),
          _metaRow(Icons.event, _formatDateRange(widget.gara)),
          if (widget.gara.localita.isNotEmpty ||
              widget.gara.sitoGara.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow(Icons.place, _locationLabel(widget.gara)),
          ],
          if (widget.gara.sport.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow(Icons.sports, widget.gara.sport),
          ],
          if (widget.gara.organizzatore.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow(Icons.apartment, widget.gara.organizzatore),
          ],
        ],
      ),
    );
  }

  Widget _buildPeopleCard({
    required String title,
    required IconData icon,
    required List<String> values,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0A66C2)),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (values.isEmpty)
            Text(
              emptyText,
              style: TextStyle(color: Colors.blueGrey.shade600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (name) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1F5FA8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD2D2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFB23636)),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF306AA3)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF27415F)),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final style = _statusStyle(status);
    final text = status.trim().isEmpty ? 'Non specificato' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: style.strong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  _StatusStyle _statusStyle(String status) {
    final upper = status.trim().toUpperCase();
    if (upper == 'DESIGNAZIONE INVIATA') {
      return const _StatusStyle(
        soft: Color(0xFFE4F0FF),
        strong: Color(0xFF1F5FA8),
      );
    }
    if (upper == 'GARA COMPLETATA' || upper == 'SICWIN OK') {
      return const _StatusStyle(
        soft: Color(0xFFE8F7EF),
        strong: Color(0xFF1D7C4B),
      );
    }
    if (upper == 'IN PROGRESS') {
      return const _StatusStyle(
        soft: Color(0xFFFFF3DE),
        strong: Color(0xFF9D6400),
      );
    }
    return const _StatusStyle(
      soft: Color(0xFFEDEFF3),
      strong: Color(0xFF515A68),
    );
  }

  String _formatDateRange(Gara gara) {
    final start = _fmtDate(gara.dataGara);
    final end =
        gara.dataGaraFine.isNotEmpty ? _fmtDate(gara.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start - $end';
    return start ?? end ?? '-';
  }

  String _locationLabel(Gara gara) {
    final localita = gara.localita.trim();
    final sito = gara.sitoGara.trim();
    if (localita.isNotEmpty && sito.isNotEmpty) return '$localita - $sito';
    if (localita.isNotEmpty) return localita;
    if (sito.isNotEmpty) return sito;
    return '-';
  }

  String? _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }
}

class _StatusStyle {
  final Color soft;
  final Color strong;

  const _StatusStyle({
    required this.soft,
    required this.strong,
  });
}
