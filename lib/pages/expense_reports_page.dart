import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/expense_report.dart';
import '../services/notion_service.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/notion_user.dart';
import '../widgets/standard_app_bar_actions.dart';

class ExpenseReportsPage extends StatefulWidget {
  const ExpenseReportsPage({
    super.key,
    required this.loggedUser,
    this.notionService,
  });

  final Map<String, dynamic> loggedUser;
  final NotionService? notionService;

  @override
  State<ExpenseReportsPage> createState() => _ExpenseReportsPageState();
}

class _ExpenseReportsPageState extends State<ExpenseReportsPage> {
  late int _year;
  late NotionService _notion;
  List<ExpenseReportSnapshot> _reports = const [];
  bool _loading = true;
  String? _error;
  String _sport = '';

  final _currency = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _year = AppConfig.currentRaceYear;
    _notion = widget.notionService ??
        NotionService(databaseId: AppConfig.raceDatabaseIds[_year]!);
    _load();
  }

  List<ExpenseReportSnapshot> get _filtered => _sport.isEmpty
      ? _reports
      : _reports.where((report) => report.sport == _sport).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _notion.fetchAdminExpenseReports();
      final reports = rows.map(ExpenseReportSnapshot.fromJson).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        if (_sport.isNotEmpty &&
            !_reports.any((item) => item.sport == _sport)) {
          _sport = '';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _changeYear(int year) async {
    if (year == _year) return;
    setState(() {
      _year = year;
      _sport = '';
      _notion = NotionService(databaseId: AppConfig.raceDatabaseIds[year]!);
    });
    await _load();
  }

  String _dateLabel(ExpenseReportSnapshot report) {
    final start = formatItalianIsoDateOrValue(report.startDate);
    final end = formatItalianIsoDateOrValue(report.endDate);
    return start == end || end.isEmpty ? start : '$start – $end';
  }

  void _showDetails(ExpenseReportSnapshot report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            Text(
              report.title.isEmpty ? 'Nota spese' : report.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text('${_dateLabel(report)} · ${report.sport}'),
            const SizedBox(height: 18),
            if (report.warnings.isNotEmpty)
              _WarningBox(warnings: report.warnings),
            if (report.warnings.isNotEmpty) const SizedBox(height: 14),
            ...report.lines.map(
              (line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.label),
                subtitle: Text([
                  if (line.date.isNotEmpty)
                    formatItalianIsoDateOrValue(line.date),
                  if (line.quantity > 0)
                    '${_quantity(line.quantity)} ${line.unit}',
                  if (line.unitRate != null)
                    '${_currency.format(line.unitRate)} / ${line.unit}',
                ].join(' · ')),
                trailing: Text(
                  _currency.format(line.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TOTALE',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  _currency.format(report.total),
                  style: const TextStyle(
                    color: Color(0xFF0755A0),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tariffario: ${report.tariffVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  @override
  Widget build(BuildContext context) {
    if (!isNotionAdmin(widget.loggedUser)) {
      return const Scaffold(
        body: Center(child: Text('Sezione riservata agli amministratori.')),
      );
    }
    final sports = _reports
        .map((report) => report.sport)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final reports = _filtered;
    final total = reports.fold<double>(0, (sum, report) => sum + report.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note spese'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Scegli anno',
            initialValue: _year,
            onSelected: _changeYear,
            itemBuilder: (context) => AppConfig.configuredRaceYears.reversed
                .map((year) => PopupMenuItem(value: year, child: Text('$year')))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text('$_year',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          ...standardAppBarActions(
            context,
            helpTitle: 'Note spese',
            helpContent: const [
              'Riepilogo economico dei rapportini calcolato con il tariffario in vigore alla data della gara.',
              'Le voci con avviso richiedono una verifica manuale prima dell’utilizzo contabile.',
            ],
            onRefresh: _load,
            refreshEnabled: !_loading,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF073B70), Color(0xFF0A66C2)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTALE CALCOLATO',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(_currency.format(total),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900)),
                            Text('${reports.length} note spese',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (sports.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _sport,
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('Tutti gli sport')),
                            ...sports.map((sport) => DropdownMenuItem(
                                value: sport, child: Text(sport))),
                          ],
                          onChanged: (value) =>
                              setState(() => _sport = value ?? ''),
                          decoration: const InputDecoration(
                            labelText: 'Filtra per sport',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (reports.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Nessuna nota spese strutturata disponibile per questo periodo.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...reports.map(
                          (report) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _showDetails(report),
                              leading: Icon(
                                report.requiresManualReview
                                    ? Icons.warning_amber_rounded
                                    : Icons.receipt_long_rounded,
                                color: report.requiresManualReview
                                    ? const Color(0xFFC46B00)
                                    : const Color(0xFF0A66C2),
                              ),
                              title: Text(
                                  report.title.isEmpty
                                      ? 'Gara senza titolo'
                                      : report.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  '${_dateLabel(report)} · ${report.sport}'),
                              trailing: Text(_currency.format(report.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4A43A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verifica manuale richiesta',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            ...warnings.map((warning) => Text('• $warning')),
          ],
        ),
      );
}
