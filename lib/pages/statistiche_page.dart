import 'package:flutter/material.dart';

import '../models/gara.dart';
import '../services/notion_service.dart';
import '../widgets/stopwatch_loading.dart';

class StatistichePage extends StatefulWidget {
  final Map<String, dynamic> loggedUser;

  const StatistichePage({super.key, required this.loggedUser});

  @override
  State<StatistichePage> createState() => _StatistichePageState();
}

class _StatistichePageState extends State<StatistichePage> {
  static const _db2025 = '2afde089ef9580e2b0e7d19d44f3a3f6';
  static const _db2026 = '2b1de089ef9580729622ff9543046cbc';

  late final NotionService _notion;
  bool _loading = true;
  String? _error;
  _StatsData _stats = const _StatsData();
  List<Gara> _allGare = const [];
  List<int> _availableYears = const [];
  int? _selectedYear;

  String? get _loggedUserId {
    final id = widget.loggedUser['id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  bool get _isAdmin {
    final props = widget.loggedUser['properties'];
    if (props is! Map<String, dynamic>) return false;

    const adminKeys = [
      'ADMIN',
      'Admin',
      'admin',
      'RUOLO',
      'Ruolo',
      'ROLE',
      'Role',
      'role',
    ];

    bool matchAdminText(String? value) {
      if (value == null) return false;
      final lower = value.toLowerCase();
      return lower == 'admin' || lower == 'amministratore';
    }

    bool hasAdminValue(Map<String, dynamic> field) {
      if (field['checkbox'] == true) return true;

      final select = field['select'];
      if (select is Map<String, dynamic>) {
        final name = select['name'];
        if (name is String && matchAdminText(name)) return true;
      }

      final multi = field['multi_select'];
      if (multi is List) {
        for (final entry in multi) {
          if (entry is Map<String, dynamic>) {
            final name = entry['name'];
            if (name is String && matchAdminText(name)) return true;
          }
        }
      }

      final rich = field['rich_text'];
      if (rich is List && rich.isNotEmpty) {
        final first = rich.first;
        if (first is Map<String, dynamic>) {
          final text = first['plain_text'];
          if (text is String && matchAdminText(text)) return true;
        }
      }

      return false;
    }

    for (final key in adminKeys) {
      final value = props[key];
      if (value is Map<String, dynamic> && hasAdminValue(value)) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _notion = NotionService(databaseId: _db2025);
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = _loggedUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _stats = const _StatsData();
          _loading = false;
        });
        return;
      }

      final results = await _notion.fetchGare(
        additionalDatabaseIds: const [_db2026],
      );
      final gare = results.map((e) => Gara.fromNotion(e)).toList();
      final years = _extractYears(gare);
      final selectedYear = _pickInitialYear(years, _selectedYear);

      if (!mounted) return;
      setState(() {
        _allGare = gare;
        _availableYears = years;
        _selectedYear = selectedYear;
        _stats = _buildStats(gare, userId, selectedYear);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectYear(int? year) {
    final userId = _loggedUserId;
    if (userId == null) return;
    setState(() {
      _selectedYear = year;
      _stats = _buildStats(_allGare, userId, year);
    });
  }

  _StatsData _buildStats(List<Gara> gare, String userId, int? year) {
    final filteredGare = _filterByYear(gare, year);
    final asCrono =
        filteredGare.where((g) => g.kronosIds.contains(userId)).toList();
    final asDsc = filteredGare.where((g) => g.dscIds.contains(userId)).toList();
    final asElaborazioneDati =
        filteredGare.where((g) => g.pcSegreteriaIds.contains(userId)).toList();

    return _StatsData(
      selectedYear: year,
      isAdmin: _isAdmin,
      allGareCount: filteredGare.length,
      cronoCount: asCrono.length,
      dscCount: asDsc.length,
      elaborazioneDatiCount: asElaborazioneDati.length,
      sportCounts: _countBySport(asCrono),
      elaborazioneDatiSportCounts: _countBySport(asElaborazioneDati),
      yearCounts: _countByYear(
        gare.where((g) => g.kronosIds.contains(userId)).toList(),
      ),
      adminSportCounts: _isAdmin ? _countBySport(filteredGare) : const [],
      latestServices: _latest(asCrono, 5),
    );
  }

  List<Gara> _filterByYear(List<Gara> gare, int? year) {
    if (year == null) return gare;
    return gare.where((g) => _yearOf(g) == year).toList();
  }

  List<int> _extractYears(List<Gara> gare) {
    final years = <int>{};
    for (final gara in gare) {
      final year = _yearOf(gara);
      if (year != null) years.add(year);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  int? _pickInitialYear(List<int> years, int? previous) {
    if (previous != null && years.contains(previous)) return previous;
    final currentYear = DateTime.now().year;
    if (years.contains(currentYear)) return currentYear;
    return years.isEmpty ? null : years.first;
  }

  int? _yearOf(Gara gara) {
    final parsed = DateTime.tryParse(gara.dataGara);
    return parsed?.year;
  }

  List<_StatEntry> _countBySport(List<Gara> gare) {
    final counts = <String, int>{};
    for (final gara in gare) {
      final sport = gara.sport.trim().isEmpty ? 'Non indicato' : gara.sport;
      counts[sport] = (counts[sport] ?? 0) + 1;
    }
    return _sortedEntries(counts);
  }

  List<_StatEntry> _countByYear(List<Gara> gare) {
    final counts = <String, int>{};
    for (final gara in gare) {
      final parsed = DateTime.tryParse(gara.dataGara);
      final year = parsed == null ? 'Senza data' : parsed.year.toString();
      counts[year] = (counts[year] ?? 0) + 1;
    }
    final entries = _sortedEntries(counts);
    entries.sort((a, b) => b.label.compareTo(a.label));
    return entries;
  }

  List<_StatEntry> _sortedEntries(Map<String, int> counts) {
    final entries =
        counts.entries.map((e) => _StatEntry(e.key, e.value)).toList();
    entries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return entries;
  }

  List<Gara> _latest(List<Gara> gare, int limit) {
    final copy = [...gare];
    copy.sort((a, b) {
      final da = DateTime.tryParse(a.dataGara);
      final db = DateTime.tryParse(b.dataGara);
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return a.titolo.toLowerCase().compareTo(b.titolo.toLowerCase());
    });
    return copy.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
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
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: _loading
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: 140,
                      child: Center(
                        child: StopwatchLoading(
                          label: 'Calcolo statistiche...',
                        ),
                      ),
                    ),
                  ],
                )
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _loadStats)
                  : _StatsView(
                      stats: _stats,
                      availableYears: _availableYears,
                      selectedYear: _selectedYear,
                      onYearChanged: _selectYear,
                    ),
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final _StatsData stats;
  final List<int> availableYears;
  final int? selectedYear;
  final ValueChanged<int?> onYearChanged;

  const _StatsView({
    required this.stats,
    required this.availableYears,
    required this.selectedYear,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _HeroCard(stats: stats),
        const SizedBox(height: 12),
        _YearSelectorCard(
          availableYears: availableYears,
          selectedYear: selectedYear,
          onChanged: onYearChanged,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final width =
                wide ? (constraints.maxWidth - 10) / 2 : double.infinity;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: width,
                  child: _CountCard(
                    icon: Icons.sports_score,
                    label: 'Designazioni come crono',
                    value: stats.cronoCount,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _CountCard(
                    icon: Icons.computer,
                    label: 'Elaborazione Dati',
                    value: stats.elaborazioneDatiCount,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _CountCard(
                    icon: Icons.assignment_ind,
                    label: 'Servizi come DSC',
                    value: stats.dscCount,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _CountCard(
                    icon: Icons.category,
                    label: 'Sport cronometrati',
                    value: stats.sportCounts.length,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: 'Designazioni per sport',
          icon: Icons.pie_chart_outline,
          entries: stats.sportCounts,
          emptyText: 'Nessuna designazione trovata.',
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: 'Elaborazione Dati per sport',
          icon: Icons.monitor_heart_outlined,
          entries: stats.elaborazioneDatiSportCounts,
          emptyText: 'Nessun servizio in Elaborazione Dati trovato.',
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: 'Designazioni per anno',
          icon: Icons.calendar_month,
          entries: stats.yearCounts,
          emptyText: 'Nessun anno disponibile.',
        ),
        const SizedBox(height: 12),
        _LatestServicesCard(gare: stats.latestServices),
        if (stats.isAdmin) ...[
          const SizedBox(height: 12),
          _BreakdownCard(
            title: 'Gare totali per sport (${stats.allGareCount}) - solo admin',
            icon: Icons.admin_panel_settings_outlined,
            entries: stats.adminSportCounts,
            emptyText: 'Nessuna gara trovata per l\'anno selezionato.',
            subtitle: 'Questa statistica e visibile solo agli admin.',
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final _StatsData stats;

  const _HeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final favoriteSport = stats.sportCounts.isEmpty
        ? 'nessuno sport'
        : stats.sportCounts.first.label;
    final yearLabel = stats.selectedYear == null
        ? 'nel periodo selezionato'
        : 'nel ${stats.selectedYear}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF004E9A), Color(0xFF0A66C2), Color(0xFF338FE5)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A66C2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiche',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hai ${stats.cronoCount} designazioni da crono $yearLabel. Lo sport piu frequente e $favoriteSport.',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _YearSelectorCard extends StatelessWidget {
  final List<int> availableYears;
  final int? selectedYear;
  final ValueChanged<int?> onChanged;

  const _YearSelectorCard({
    required this.availableYears,
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_month, color: Color(0xFF0A66C2)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Anno statistiche',
              style: TextStyle(
                color: Color(0xFF1A2B40),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int?>(
            value: selectedYear,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Tutti'),
              ),
              ...availableYears.map(
                (year) => DropdownMenuItem<int?>(
                  value: year,
                  child: Text(year.toString()),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _CountCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0A66C2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF49627E),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF1A2B40),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_StatEntry> entries;
  final String emptyText;
  final String? subtitle;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.entries,
    required this.emptyText,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final max = entries.isEmpty ? 1 : entries.first.count;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0A66C2)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A2B40),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF49627E),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(color: Color(0xFF49627E)),
            )
          else
            ...entries.map((entry) {
              final percent = entry.count / max;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A2B40),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          entry.count.toString(),
                          style: const TextStyle(
                            color: Color(0xFF0A66C2),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFEAF3FF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0A66C2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _LatestServicesCard extends StatelessWidget {
  final List<Gara> gare;

  const _LatestServicesCard({required this.gare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Color(0xFF0A66C2)),
              SizedBox(width: 8),
              Text(
                'Ultime designazioni',
                style: TextStyle(
                  color: Color(0xFF1A2B40),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (gare.isEmpty)
            const Text(
              'Nessuna designazione trovata.',
              style: TextStyle(color: Color(0xFF49627E)),
            )
          else
            ...gare.map(
              (gara) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available,
                      color: Color(0xFF7B8EA3),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gara.titolo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A2B40),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_formatDate(gara.dataGara)} - ${gara.sport.isEmpty ? 'Sport non indicato' : gara.sport}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF49627E),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(borderColor: const Color(0xFFFFD8D8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Errore nel caricamento delle statistiche',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(error),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsData {
  final int? selectedYear;
  final bool isAdmin;
  final int allGareCount;
  final int cronoCount;
  final int dscCount;
  final int elaborazioneDatiCount;
  final List<_StatEntry> sportCounts;
  final List<_StatEntry> elaborazioneDatiSportCounts;
  final List<_StatEntry> yearCounts;
  final List<_StatEntry> adminSportCounts;
  final List<Gara> latestServices;

  const _StatsData({
    this.selectedYear,
    this.isAdmin = false,
    this.allGareCount = 0,
    this.cronoCount = 0,
    this.dscCount = 0,
    this.elaborazioneDatiCount = 0,
    this.sportCounts = const [],
    this.elaborazioneDatiSportCounts = const [],
    this.yearCounts = const [],
    this.adminSportCounts = const [],
    this.latestServices = const [],
  });
}

class _StatEntry {
  final String label;
  final int count;

  const _StatEntry(this.label, this.count);
}

BoxDecoration _panelDecoration({
  Color borderColor = const Color(0xFFDCE8F6),
}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(
        color: Color(0x11000000),
        blurRadius: 14,
        offset: Offset(0, 5),
      ),
    ],
  );
}

String _formatDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso.isEmpty ? '-' : iso;
  final dd = parsed.day.toString().padLeft(2, '0');
  final mm = parsed.month.toString().padLeft(2, '0');
  return '$dd/$mm/${parsed.year}';
}
