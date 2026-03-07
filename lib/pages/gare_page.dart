import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/help_content.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../widgets/help_dialog.dart';
import 'dettaglio_gara.dart';

class GarePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  const GarePage({super.key, required this.loggedUser});

  @override
  State<GarePage> createState() => _GarePageState();
}

class _GarePageState extends State<GarePage> {
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';

  late NotionService notion;
  List<Gara> gare = [];
  bool loading = true;
  Set<String> updatingGare = {};
  Set<String> expandedMonths = {};

  @override
  void initState() {
    super.initState();

    notion = NotionService(
      apiKey: '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',
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
          return -1;
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
                ? 'Ti sei reso disponibile per ${gara.titolo}'
                : 'Hai annullato la disponibilita per ${gara.titolo}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingGare.remove(gara.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _garePerMese();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario gare'),
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
                onRefresh: () => load(showSpinner: false),
                child: grouped.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                        children: [
                          ...grouped.entries.map(_buildMonthSection),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 44, color: Colors.blueGrey.shade300),
              const SizedBox(height: 10),
              const Text(
                'Nessuna gara disponibile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Quando verranno aggiunte nuove gare in Notion, le vedrai qui.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => load(showSpinner: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSection(MapEntry<String, List<Gara>> entry) {
    final isExpanded = expandedMonths.contains(entry.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F6)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(entry.key),
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${entry.value.length}',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
          children: entry.value
              .map((g) => Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: _buildRaceCard(g),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRaceCard(Gara g) {
    final showAction = _loggedUserId != null;
    final candidabile = _puoCandidarsi(g);
    final statusStyle = _statusStyle(g.status);

    return Material(
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 110,
                  decoration: BoxDecoration(
                    color: statusStyle.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                      if (showAction && candidabile) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: updatingGare.contains(g.id)
                              ? null
                              : () =>
                                  _toggleDisponibilita(g, !_isUserAssigned(g)),
                          icon: updatingGare.contains(g.id)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_isUserAssigned(g)
                                  ? Icons.person_remove_alt_1
                                  : Icons.person_add_alt_1),
                          label: Text(_isUserAssigned(g)
                              ? 'Rimuovimi dalla gara'
                              : 'Mi rendo disponibile'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0A66C2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
    final end =
        gara.dataGaraFine.isNotEmpty ? _fmtDate(gara.dataGaraFine) : start;
    if (start == null && end == null) return '-';
    if (start != null && end != null && start != end) return '$start - $end';
    return start ?? end ?? '-';
  }

  String? _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return null;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  _StatusStyle _statusStyle(String status) {
    final upper = status.trim().toUpperCase();
    if (upper == 'DESIGNAZIONE INVIATA') {
      return const _StatusStyle(
        soft: Color(0xFFE4F0FF),
        strong: Color(0xFF1F5FA8),
        accent: Color(0xFF2D83D6),
      );
    }
    if (upper == 'GARA COMPLETATA' || upper == 'SICWIN OK') {
      return const _StatusStyle(
        soft: Color(0xFFE8F7EF),
        strong: Color(0xFF1D7C4B),
        accent: Color(0xFF2EA568),
      );
    }
    if (upper == 'IN PROGRESS') {
      return const _StatusStyle(
        soft: Color(0xFFFFF3DE),
        strong: Color(0xFF9D6400),
        accent: Color(0xFFE2A53C),
      );
    }
    return const _StatusStyle(
      soft: Color(0xFFEDEFF3),
      strong: Color(0xFF515A68),
      accent: Color(0xFF8B95A5),
    );
  }

  Widget _statusChip(String status) {
    final style = _statusStyle(status);
    final text = status.trim().isEmpty ? 'N/D' : Gara.statusLabel(status);
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
}

class _StatusStyle {
  final Color soft;
  final Color strong;
  final Color accent;

  const _StatusStyle({
    required this.soft,
    required this.strong,
    required this.accent,
  });
}
