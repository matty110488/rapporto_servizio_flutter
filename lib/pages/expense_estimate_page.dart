import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/expense_report.dart';
import '../services/notion_service.dart';
import '../utils/notion_user.dart';
import '../widgets/standard_app_bar_actions.dart';

class ExpenseEstimatePage extends StatefulWidget {
  const ExpenseEstimatePage({
    super.key,
    required this.loggedUser,
    this.notionService,
  });

  final Map<String, dynamic> loggedUser;
  final NotionService? notionService;

  @override
  State<ExpenseEstimatePage> createState() => _ExpenseEstimatePageState();
}

class _ExpenseEstimatePageState extends State<ExpenseEstimatePage> {
  static const _sports = [
    'Atletica - Strada',
    'Atletica - Pista',
    'Ciclismo',
    'Corsa',
    'Corsa - FIDAL',
    'Corsa in montagna',
    'Hockey ghiaccio',
    'Nuoto',
    'Rally',
    'Regolarita auto',
    'Regolarita storiche',
    'Sci Alpinismo',
    'Sci Alpino FIS',
    'Sci Alpino FISI',
    'Sci Nordico / Biathlon FISI',
    'Sci Nordico / Biathlon FIS',
    'Snowboard FISI',
    'Snowboard FIS',
    'Altro (specificare)',
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _days = TextEditingController(text: '1');
  final _ordinary = TextEditingController(text: '2');
  final _specialists = TextEditingController(text: '0');
  final _hours = TextEditingController(text: '4');
  final _km = TextEditingController(text: '0');
  final _otherExpenses = TextEditingController(text: '0');
  final _scoreboards = TextEditingController(text: '0');
  final _intermediates = TextEditingController(text: '0');
  final _transmissions = TextEditingController(text: '0');
  final _idCams = TextEditingController(text: '0');

  late final NotionService _notion;
  late DateTime _date;
  String _sport = 'Corsa';
  ExpenseReportSnapshot? _estimate;
  bool _calculating = false;
  String? _error;

  final _currency = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _notion = widget.notionService ??
        NotionService(databaseId: AppConfig.currentRaceDatabaseId);
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _location,
      _days,
      _ordinary,
      _specialists,
      _hours,
      _km,
      _otherExpenses,
      _scoreboards,
      _intermediates,
      _transmissions,
      _idCams,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _integer(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String? _validateInteger(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return 'Inserisci un numero intero positivo';
    }
    return null;
  }

  String? _validateCount(String? value) {
    final baseError = _validateInteger(value);
    if (baseError != null) {
      return baseError;
    }
    if ((int.tryParse(value!.trim()) ?? 0) > 100) {
      return 'Il valore massimo è 100';
    }
    return null;
  }

  String? _validateDays(String? value) {
    final baseError = _validateInteger(value);
    if (baseError != null) {
      return baseError;
    }
    final days = int.tryParse(value!.trim()) ?? 0;
    if (days < 1 || days > 31) {
      return 'Inserisci da 1 a 31 giornate';
    }
    return null;
  }

  String? _validateNumber(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      return 'Inserisci un valore positivo';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2026, 4),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _reset() {
    _title.clear();
    _location.clear();
    _days.text = '1';
    _ordinary.text = '2';
    _specialists.text = '0';
    _hours.text = '4';
    _km.text = '0';
    _otherExpenses.text = '0';
    _scoreboards.text = '0';
    _intermediates.text = '0';
    _transmissions.text = '0';
    _idCams.text = '0';
    setState(() {
      _date = DateTime.now();
      _sport = 'Corsa';
      _estimate = null;
      _error = null;
    });
  }

  Map<String, dynamic> _buildReport() {
    final requestedDays = _integer(_days);
    final dayCount = requestedDays < 1
        ? 1
        : requestedDays > 31
            ? 31
            : requestedDays;
    final dates = List.generate(
      dayCount,
      (index) => _isoDate(_date.add(Duration(days: index))),
    );
    final people = <Map<String, dynamic>>[];
    final hours = _number(_hours);

    void addPeople(int count, {required bool specialist}) {
      for (var index = 0; index < count; index++) {
        people.add({
          'nome': specialist
              ? 'Specialista ${index + 1}'
              : 'Cronometrista ${index + 1}',
          'segreteria': specialist ? 'SI' : 'NO',
          'giorni': dates
              .map((date) => {
                    'data': date,
                    'ore': hours,
                    'km': 0,
                    'spese': 0,
                  })
              .toList(),
        });
      }
    }

    addPeople(_integer(_ordinary), specialist: false);
    addPeople(_integer(_specialists), specialist: true);
    if (people.isEmpty) {
      people.add({
        'nome': 'Trasferta',
        'segreteria': 'NO',
        'giorni': dates
            .map((date) => {'data': date, 'ore': 0, 'km': 0, 'spese': 0})
            .toList(),
      });
    }
    final firstDays = people.first['giorni'] as List<dynamic>;
    final firstDay = firstDays.first as Map<String, dynamic>;
    firstDay['km'] = _number(_km);
    firstDay['spese'] = _number(_otherExpenses);

    Map<String, dynamic> equipmentCount(
      String field,
      String countField,
      int count,
    ) =>
        {
          field: count > 0 ? 'SI' : 'NO',
          countField: count,
        };

    return {
      'gara': {
        'nome': _title.text.trim().isEmpty ? 'Preventivo' : _title.text.trim(),
        'sport': _sport,
        'luogo': _location.text.trim(),
      },
      'cronometristi': people,
      'pacchetto': {'giornate': dates},
      'apparecchiature': [
        {
          'guidedMode': true,
          ...equipmentCount(
            'tabellone',
            'tabelloneNumero',
            _integer(_scoreboards),
          ),
          ...equipmentCount(
            'intermedi',
            'intermediNumero',
            _integer(_intermediates),
          ),
          ...equipmentCount(
            'trasmissioneDati',
            'trasmissioneDatiNumero',
            _integer(_transmissions),
          ),
          ...equipmentCount('IDcam', 'IDcamNumero', _integer(_idCams)),
        },
      ],
    };
  }

  Future<void> _calculate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _calculating = true;
      _error = null;
      _estimate = null;
    });
    try {
      final result =
          await _notion.calculateExpenseEstimate(report: _buildReport());
      if (!mounted) {
        return;
      }
      setState(() {
        _estimate = ExpenseReportSnapshot.fromJson(result);
        _calculating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _calculating = false;
      });
    }
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    bool decimal = false,
    String? helper,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        validator: validator ?? (decimal ? _validateNumber : _validateInteger),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!isNotionAdmin(widget.loggedUser)) {
      return const Scaffold(
        body: Center(child: Text('Sezione riservata agli amministratori.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preventivi'),
        actions: standardAppBarActions(
          context,
          helpTitle: 'Preventivi',
          helpContent: const [
            'Simula il costo di una gara usando il tariffario in vigore alla data indicata.',
            'I chilometri e le altre spese sono totali per l’intero servizio.',
            'Il calcolo non viene salvato in Notion.',
          ],
          onRefresh: _reset,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Gara',
              icon: Icons.sports_score_outlined,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Titolo del preventivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Località',
                    border: OutlineInputBorder(),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _sport,
                  decoration: const InputDecoration(
                    labelText: 'Sport',
                    border: OutlineInputBorder(),
                  ),
                  items: _sports
                      .map((sport) =>
                          DropdownMenuItem(value: sport, child: Text(sport)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _sport = value ?? _sport),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        'Giornate',
                        _days,
                        validator: _validateDays,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _Section(
              title: 'Personale e trasferta',
              icon: Icons.groups_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'Cronometristi',
                        _ordinary,
                        validator: _validateCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        'Specialisti / ED',
                        _specialists,
                        validator: _validateCount,
                      ),
                    ),
                  ],
                ),
                _numberField(
                  'Ore per persona al giorno',
                  _hours,
                  decimal: true,
                ),
                _numberField(
                  'Km complessivi',
                  _km,
                  decimal: true,
                  helper: 'Rimborso calcolato a 0,36 €/km',
                ),
                _numberField(
                  'Altre spese complessive',
                  _otherExpenses,
                  decimal: true,
                ),
              ],
            ),
            _Section(
              title: 'Apparecchiature extra',
              icon: Icons.settings_input_component_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'Tabelloni',
                        _scoreboards,
                        validator: _validateCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        'Intermedi',
                        _intermediates,
                        validator: _validateCount,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        'Trasmissioni',
                        _transmissions,
                        validator: _validateCount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        'IDcam',
                        _idCams,
                        validator: _validateCount,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _calculating ? null : _calculate,
              icon: _calculating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(_calculating ? 'Calcolo…' : 'Calcola preventivo'),
            ),
            if (_estimate != null) ...[
              const SizedBox(height: 20),
              _EstimateResult(estimate: _estimate!, currency: _currency),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF0A66C2)),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      );
}

class _EstimateResult extends StatelessWidget {
  const _EstimateResult({required this.estimate, required this.currency});

  final ExpenseReportSnapshot estimate;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF9EC8EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TOTALE PREVENTIVO',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              currency.format(estimate.total),
              style: const TextStyle(
                color: Color(0xFF0755A0),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (estimate.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifica manuale richiesta',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    ...estimate.warnings.map((warning) => Text('• $warning')),
                  ],
                ),
              ),
            ],
            const Divider(height: 28),
            ...estimate.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(line.label)),
                    const SizedBox(width: 10),
                    Text(
                      currency.format(line.amount),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Tariffario: ${estimate.tariffVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 3),
            Text(
              'Simulazione non salvata in Notion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}
