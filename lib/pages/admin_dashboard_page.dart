import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../constants/help_content.dart';
import '../models/admin_dashboard_data.dart';
import '../models/gara.dart';
import '../services/notion_service.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/notion_user.dart';
import '../widgets/standard_app_bar_actions.dart';
import 'dettaglio_gara.dart';
import 'expense_estimate_page.dart';
import 'expense_reports_page.dart';
import 'gare_page.dart';
import 'notifications_page.dart';
import 'service_reports_page.dart';
import 'statistiche_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.loggedUser,
    this.notionService,
  });

  final Map<String, dynamic> loggedUser;
  final NotionService? notionService;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final NotionService _notion;
  AdminDashboardData _data = const AdminDashboardData();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notion = widget.notionService ??
        NotionService(databaseId: AppConfig.currentRaceDatabaseId);
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _notion.fetchGare(forceRefresh: forceRefresh);
      final gare = rows.map(Gara.fromNotion).toList();
      if (!mounted) return;
      setState(() {
        _data = AdminDashboardData.fromGare(gare);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  void _openRace(Gara gara) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DettaglioGara(
          gara: gara,
          loggedUser: widget.loggedUser,
          notionService: _notion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isNotionAdmin(widget.loggedUser)) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Questa sezione è riservata agli amministratori.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro di controllo Admin'),
        actions: standardAppBarActions(
          context,
          helpTitle: 'Centro di controllo Admin',
          helpContent: HelpContent.adminDashboard,
          onRefresh: () => _load(forceRefresh: true),
          refreshEnabled: !_loading,
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F2FF),
              Color(0xFFF7FBFF),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(
                      error: _error!,
                      onRetry: () => _load(forceRefresh: true),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(forceRefresh: true),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final horizontal =
                              constraints.maxWidth >= 980 ? 28.0 : 16.0;
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              18,
                              horizontal,
                              32,
                            ),
                            children: [
                              _Header(data: _data),
                              const SizedBox(height: 16),
                              _KpiGrid(data: _data),
                              const SizedBox(height: 24),
                              if (constraints.maxWidth >= 980)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: _AttentionPanel(
                                        data: _data,
                                        onOpenRace: _openRace,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        children: [
                                          _UpcomingPanel(
                                            races: _data.upcomingRaces,
                                            onOpenRace: _openRace,
                                          ),
                                          const SizedBox(height: 16),
                                          _QuickActions(
                                            loggedUser: widget.loggedUser,
                                            onOpen: _open,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _AttentionPanel(
                                  data: _data,
                                  onOpenRace: _openRace,
                                ),
                                const SizedBox(height: 16),
                                _UpcomingPanel(
                                  races: _data.upcomingRaces,
                                  onOpenRace: _openRace,
                                ),
                                const SizedBox(height: 16),
                                _QuickActions(
                                  loggedUser: widget.loggedUser,
                                  onOpen: _open,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final total = data.attentionItems.length;
    final hasAttention = total > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073B70), Color(0xFF0A66C2)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300A66C2),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CENTRO DI CONTROLLO ADMIN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAttention
                      ? '$total attività richiedono attenzione'
                      : 'Nessuna criticità operativa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Riepilogo delle gare e dei rapportini da gestire.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _KpiCard(
              width: width,
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF0A66C2),
              value: data.upcomingRaces.length,
              label: 'Gare nei prossimi 30 giorni',
            ),
            _KpiCard(
              width: width,
              icon: Icons.groups_2_outlined,
              color: const Color(0xFFC46B00),
              value: data.incompleteDesignations.length,
              label: 'Designazioni incomplete',
            ),
            _KpiCard(
              width: width,
              icon: Icons.assignment_late_outlined,
              color: const Color(0xFFB3261E),
              value: data.pendingReports.length,
              label: 'Rapportini da ricevere',
            ),
            _KpiCard(
              width: width,
              icon: Icons.rule_folder_outlined,
              color: const Color(0xFF6B4EA0),
              value: data.incompleteData.length,
              label: 'Gare con dati incompleti',
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF41566E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AttentionFilter { all, designations, reports, data }

class _AttentionPanel extends StatefulWidget {
  const _AttentionPanel({
    required this.data,
    required this.onOpenRace,
  });

  final AdminDashboardData data;
  final ValueChanged<Gara> onOpenRace;

  @override
  State<_AttentionPanel> createState() => _AttentionPanelState();
}

class _AttentionPanelState extends State<_AttentionPanel> {
  _AttentionFilter _filter = _AttentionFilter.all;

  List<AdminAttentionItem> get _filteredItems {
    return widget.data.attentionItems.where((item) {
      return switch (_filter) {
        _AttentionFilter.all => true,
        _AttentionFilter.designations =>
          item.type == AdminAttentionType.incompleteDesignation,
        _AttentionFilter.reports =>
          item.type == AdminAttentionType.pendingReport,
        _AttentionFilter.data => item.type == AdminAttentionType.incompleteData,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final items = filteredItems.take(8).toList();
    final filters = [
      (
        _AttentionFilter.all,
        'Tutte',
        widget.data.attentionItems.length,
      ),
      (
        _AttentionFilter.designations,
        'Designazioni',
        widget.data.incompleteDesignations.length,
      ),
      (
        _AttentionFilter.reports,
        'Rapportini',
        widget.data.pendingReports.length,
      ),
      (
        _AttentionFilter.data,
        'Dati',
        widget.data.incompleteData.length,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.priority_high_rounded,
            title: 'Azioni richieste',
            subtitle: 'Le situazioni da sistemare per prime',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${filter.$2} ${filter.$3}'),
                        selected: _filter == filter.$1,
                        selectedColor: const Color(0xFFDCEEFF),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _filter == filter.$1
                              ? const Color(0xFF0A66C2)
                              : const Color(0xFFD7E4F2),
                        ),
                        labelStyle: TextStyle(
                          color: _filter == filter.$1
                              ? const Color(0xFF0755A0)
                              : const Color(0xFF41566E),
                          fontWeight: FontWeight.w800,
                        ),
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _filter = filter.$1);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _EmptyMessage(
              icon: Icons.check_circle_outline_rounded,
              title: _filter == _AttentionFilter.all
                  ? 'Tutto sotto controllo'
                  : 'Nessuna criticità in questo filtro',
              subtitle: _filter == _AttentionFilter.all
                  ? 'Non risultano criticità operative.'
                  : 'Prova un’altra categoria.',
            )
          else ...[
            ...items.map(
              (item) => _AttentionTile(
                item: item,
                onTap: () => widget.onOpenRace(item.gara),
              ),
            ),
            if (filteredItems.length > items.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Altre ${filteredItems.length - items.length} attività '
                  'non mostrate.',
                  style: const TextStyle(
                    color: Color(0xFF52657B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.item,
    required this.onTap,
  });

  final AdminAttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.type) {
      AdminAttentionType.incompleteDesignation => (
          Icons.groups_2_outlined,
          const Color(0xFFC46B00),
        ),
      AdminAttentionType.pendingReport => (
          Icons.assignment_late_outlined,
          const Color(0xFFB3261E),
        ),
      AdminAttentionType.incompleteData => (
          Icons.rule_folder_outlined,
          const Color(0xFF6B4EA0),
        ),
    };
    final urgencyColor = switch (item.urgency) {
      AdminAttentionUrgency.critical => const Color(0xFFB3261E),
      AdminAttentionUrgency.warning => const Color(0xFFC46B00),
      AdminAttentionUrgency.normal => const Color(0xFF0A66C2),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.gara.titolo.trim().isEmpty
                            ? 'Gara senza titolo'
                            : item.gara.titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dateLabel(item.gara)} · ${item.message}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: urgencyColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: urgencyColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.timingLabel,
                              style: TextStyle(
                                color: urgencyColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({
    required this.races,
    required this.onOpenRace,
  });

  final List<Gara> races;
  final ValueChanged<Gara> onOpenRace;

  @override
  Widget build(BuildContext context) {
    final visible = races.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.calendar_month_outlined,
            title: 'Prossime gare',
            subtitle: 'Orizzonte operativo di 30 giorni',
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const _EmptyMessage(
              icon: Icons.event_available_outlined,
              title: 'Nessuna gara imminente',
              subtitle: 'Non risultano eventi nei prossimi 30 giorni.',
            )
          else
            ...visible.map(
              (gara) => Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onTap: () => onOpenRace(gara),
                  leading: Container(
                    width: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _shortDate(gara),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0A66C2),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    gara.titolo.trim().isEmpty
                        ? 'Gara senza titolo'
                        : gara.titolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      if (gara.sport.trim().isNotEmpty) gara.sport,
                      if (gara.localita.trim().isNotEmpty) gara.localita,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.loggedUser,
    required this.onOpen,
  });

  final Map<String, dynamic> loggedUser;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.edit_calendar_outlined,
        'Calendario',
        () => onOpen(GarePage(loggedUser: loggedUser)),
      ),
      (
        Icons.assignment_outlined,
        'Rapportini',
        () => onOpen(ServiceReportsPage(loggedUser: loggedUser)),
      ),
      (
        Icons.insights_outlined,
        'Statistiche',
        () => onOpen(StatistichePage(loggedUser: loggedUser)),
      ),
      (
        Icons.receipt_long_outlined,
        'Note spese',
        () => onOpen(ExpenseReportsPage(loggedUser: loggedUser)),
      ),
      (
        Icons.calculate_outlined,
        'Preventivi',
        () => onOpen(ExpenseEstimatePage(loggedUser: loggedUser)),
      ),
      (
        Icons.notifications_active_outlined,
        'Notifiche',
        () => onOpen(NotificationsPage(loggedUser: loggedUser)),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.bolt_rounded,
            title: 'Azioni rapide',
            subtitle: 'Apri gli strumenti amministrativi',
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return OutlinedButton(
                onPressed: action.$3,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.$1),
                    const SizedBox(width: 8),
                    Text(
                      action.$2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0A66C2)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF52657B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF176B42)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
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
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 50),
                  const SizedBox(height: 12),
                  const Text(
                    'Impossibile caricare il riepilogo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(19),
    border: Border.all(color: const Color(0xFFDCE8F6)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x10000000),
        blurRadius: 14,
        offset: Offset(0, 5),
      ),
    ],
  );
}

String _dateLabel(Gara gara) =>
    formatItalianIsoDate(gara.dataGara) ?? 'Data non disponibile';

String _shortDate(Gara gara) {
  final date = DateTime.tryParse(gara.dataGara);
  if (date == null) return 'N/D';
  return '${italianShortWeekday(date)}\n'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}
