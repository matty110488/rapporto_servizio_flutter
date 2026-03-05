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
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';

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
      apiKey: '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',
      databaseId: _db2025,
    );
    _caricaGare();
  }

  Future<void> _caricaGare() async {
    setState(() {
      loading = true;
      errore = null;
    });
    try {
      final results = await notion.fetchGare(
        additionalDatabaseIds: const [_db2026],
      );
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: loading
            ? _buildLoadingState()
            : RefreshIndicator(
                onRefresh: _caricaGare,
                child: errore != null
                    ? _buildErrorState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        children: [
                          _buildSection(
                            title: 'Servizi da svolgere',
                            icon: Icons.pending_actions,
                            items: gareDaSvolgere,
                            emptyText: 'Nessun servizio da svolgere.',
                          ),
                          const SizedBox(height: 10),
                          _buildSection(
                            title: 'Servizi conclusi',
                            icon: Icons.verified,
                            items: gareConcluse,
                            emptyText: 'Nessun servizio concluso.',
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD8D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Errore nel recupero delle designazioni',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(errore ?? ''),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _caricaGare,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Gara> items,
    required String emptyText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0A66C2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: Color(0xFF3A597A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: TextStyle(color: Colors.blueGrey.shade600),
                ),
              )
            else
              ...items.map(_buildRaceCard),
          ],
        ),
      ),
    );
  }

  Widget _buildRaceCard(Gara g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DettaglioGara(gara: g),
              ),
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFF9FCFF),
              border: Border.all(color: const Color(0xFFD9E8FA)),
            ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(g.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _metaRow(Icons.event, _formatDateRange(g)),
                  if (g.localita.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _metaRow(Icons.place, g.localita),
                  ],
                  if (g.sport.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _metaRow(Icons.sports, g.sport),
                  ],
                ],
              ),
            ),
          ),
        ),
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
    final text = status.trim().isEmpty ? 'N/D' : status;
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
    return const _StatusStyle(
      soft: Color(0xFFE8F7EF),
      strong: Color(0xFF1D7C4B),
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
}

class _StatusStyle {
  final Color soft;
  final Color strong;

  const _StatusStyle({
    required this.soft,
    required this.strong,
  });
}
