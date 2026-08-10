import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/person_name_formatter.dart';

class GaraForm extends StatefulWidget {
  final ValueChanged<String>? onSportChanged;
  final ValueChanged<String?>? onElaborazioneDatiChanged;
  final void Function(DateTime?, DateTime?)? onDateRangeChanged;
  final ValueChanged<Map<String, Map<String, String>>>? onOrariChanged;
  const GaraForm({
    super.key,
    this.onSportChanged,
    this.onElaborazioneDatiChanged,
    this.onDateRangeChanged,
    this.onOrariChanged,
  });

  @override
  GaraFormState createState() => GaraFormState();
}

class GaraFormState extends State<GaraForm> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController organizzatoreController = TextEditingController();
  final TextEditingController luogoController = TextEditingController();
  final TextEditingController dscController = TextEditingController();
  final TextEditingController elaborazioneDatiController =
      TextEditingController();
  String sport = '';
  DateTime? dataDa;
  DateTime? dataA;
  Map<String, Map<String, String>> orariPerData = {};

  String? get _elaborazioneDatiValue {
    final value = elaborazioneDatiController.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _selezionaData(BuildContext context, bool isDa) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isDa) {
          dataDa = picked;
        } else {
          dataA = picked;
        }
        _syncOrariWithRange();
      });
      widget.onDateRangeChanged?.call(dataDa, dataA);
      widget.onOrariChanged?.call(getOrariGiornata());
    }
  }

  Map<String, dynamic> getData() {
    return {
      'nome': nomeController.text,
      'organizzatore': organizzatoreController.text,
      'sport': sport,
      'luogo': luogoController.text,
      'dataDa': dataDa != null
          ? "${dataDa!.year}-${_2(dataDa!.month)}-${_2(dataDa!.day)}"
          : '',
      'dataA': dataA != null
          ? "${dataA!.year}-${_2(dataA!.month)}-${_2(dataA!.day)}"
          : '',
      'dsc': formatPersonName(dscController.text),
      'elaborazioneDati': formatPersonName(elaborazioneDatiController.text),
    };
  }

  Map<String, Map<String, String>> getOrariGiornata() =>
      Map<String, Map<String, String>>.from(orariPerData);

  @override
  void dispose() {
    nomeController.dispose();
    organizzatoreController.dispose();
    luogoController.dispose();
    dscController.dispose();
    elaborazioneDatiController.dispose();
    super.dispose();
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  void _syncOrariWithRange() {
    if (dataDa == null || dataA == null || dataA!.isBefore(dataDa!)) {
      orariPerData = {};
      return;
    }
    final total = dataA!.difference(dataDa!).inDays + 1;
    final Map<String, Map<String, String>> updated = {};
    for (int i = 0; i < total; i++) {
      final d = DateTime(dataDa!.year, dataDa!.month, dataDa!.day)
          .add(Duration(days: i));
      final iso = "${d.year}-${_2(d.month)}-${_2(d.day)}";
      final existing = orariPerData[iso] ?? {};
      updated[iso] = {
        'oraDa': (existing['oraDa'] ?? '').toString(),
        'oraA': (existing['oraA'] ?? '').toString(),
        'pausa': (existing['pausa'] ?? 'false').toString(),
        'pausaOre': (existing['pausaOre'] ?? '').toString(),
        'pausaMinuti': (existing['pausaMinuti'] ?? '').toString(),
      };
    }
    orariPerData = updated;
  }

  void _syncOrariWithDates(List<DateTime> dates) {
    final normalized = <String, DateTime>{};
    for (final date in dates) {
      final day = DateTime(date.year, date.month, date.day);
      normalized['${day.year}-${_2(day.month)}-${_2(day.day)}'] = day;
    }
    final ordered = normalized.entries.toList()
      ..sort((first, second) => first.value.compareTo(second.value));
    final updated = <String, Map<String, String>>{};
    for (final entry in ordered) {
      final existing = orariPerData[entry.key] ?? const {};
      updated[entry.key] = {
        'oraDa': (existing['oraDa'] ?? '').toString(),
        'oraA': (existing['oraA'] ?? '').toString(),
        'pausa': (existing['pausa'] ?? 'false').toString(),
        'pausaOre': (existing['pausaOre'] ?? '').toString(),
        'pausaMinuti': (existing['pausaMinuti'] ?? '').toString(),
      };
    }
    orariPerData = updated;
  }

  void _aggiornaOrarioPerData(String data, String campo, String valore) {
    _aggiornaCampiPerData(data, {campo: valore});
  }

  void _aggiornaCampiPerData(String data, Map<String, String> aggiornamenti) {
    setState(() {
      final corrente = Map<String, String>.from(orariPerData[data] ?? {});
      corrente.addAll(aggiornamenti);
      orariPerData[data] = {
        'oraDa': (corrente['oraDa'] ?? '').toString(),
        'oraA': (corrente['oraA'] ?? '').toString(),
        'pausa': (corrente['pausa'] ?? 'false').toString(),
        'pausaOre': (corrente['pausaOre'] ?? '').toString(),
        'pausaMinuti': (corrente['pausaMinuti'] ?? '').toString(),
      };
    });
    widget.onOrariChanged?.call(getOrariGiornata());
  }

  _TimeSelection? _parseTime(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return _TimeSelection(hour, minute);
  }

  void applyNotionData({
    required String nome,
    required String organizzatore,
    required String sportValue,
    required String luogo,
    required String dataInizio,
    required String dataFine,
    String? dsc,
    String? elaborazioneDati,
  }) {
    final start = _parseDate(dataInizio);
    final end = _parseDate(dataFine.isNotEmpty ? dataFine : dataInizio);
    setState(() {
      nomeController.text = nome;
      organizzatoreController.text = organizzatore;
      luogoController.text = luogo;
      sport = sportValue;
      dataDa = start;
      dataA = end;
      _syncOrariWithRange();
      if (dsc != null) {
        dscController.text = formatPersonName(dsc);
      }
      elaborazioneDatiController.text = formatPersonName(elaborazioneDati);
    });
    widget.onSportChanged?.call(sport);
    widget.onDateRangeChanged?.call(dataDa, dataA);
    widget.onOrariChanged?.call(getOrariGiornata());
    widget.onElaborazioneDatiChanged?.call(_elaborazioneDatiValue);
  }

  void applyPackageData({
    required String nome,
    required String organizzatore,
    required String sportValue,
    required String luogo,
    required List<DateTime> dates,
    String? dsc,
    String? elaborazioneDati,
  }) {
    final ordered = dates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort();
    setState(() {
      nomeController.text = nome;
      organizzatoreController.text = organizzatore;
      luogoController.text = luogo;
      sport = sportValue;
      dataDa = ordered.isEmpty ? null : ordered.first;
      dataA = ordered.isEmpty ? null : ordered.last;
      dscController.text = formatPersonName(dsc);
      elaborazioneDatiController.text = formatPersonName(elaborazioneDati);
      _syncOrariWithDates(ordered);
    });
    widget.onSportChanged?.call(sport);
    widget.onDateRangeChanged?.call(dataDa, dataA);
    widget.onOrariChanged?.call(getOrariGiornata());
    widget.onElaborazioneDatiChanged?.call(_elaborazioneDatiValue);
  }

  void applySavedData({
    required Map<String, dynamic> garaData,
    Map<String, dynamic>? savedOrari,
  }) {
    final start = _parseDate((garaData['dataDa'] ?? '').toString());
    final end = _parseDate((garaData['dataA'] ?? '').toString());

    final normalizedOrari = <String, Map<String, String>>{};
    if (savedOrari != null) {
      savedOrari.forEach((key, value) {
        if (value is Map) {
          normalizedOrari[key.toString()] = {
            'oraDa': (value['oraDa'] ?? '').toString(),
            'oraA': (value['oraA'] ?? '').toString(),
            'pausa': (value['pausa'] ?? 'false').toString(),
            'pausaOre': (value['pausaOre'] ?? '').toString(),
            'pausaMinuti': (value['pausaMinuti'] ?? '').toString(),
          };
        }
      });
    }

    setState(() {
      nomeController.text = (garaData['nome'] ?? '').toString();
      organizzatoreController.text =
          (garaData['organizzatore'] ?? '').toString();
      luogoController.text = (garaData['luogo'] ?? '').toString();
      dscController.text = formatPersonName(garaData['dsc']);
      elaborazioneDatiController.text =
          formatPersonName(garaData['elaborazioneDati']);
      sport = (garaData['sport'] ?? '').toString();
      dataDa = start;
      dataA = end ?? start;
      _syncOrariWithRange();
      if (normalizedOrari.isNotEmpty) {
        orariPerData = Map<String, Map<String, String>>.from(normalizedOrari);
      }
    });

    widget.onSportChanged?.call(sport);
    widget.onDateRangeChanged?.call(dataDa, dataA);
    widget.onOrariChanged?.call(getOrariGiornata());
    widget.onElaborazioneDatiChanged?.call(_elaborazioneDatiValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Informazioni Gara",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildTextField("Nome Gara", nomeController),
        _buildTextField("Organizzatore", organizzatoreController),
        _buildDropdownSport(),
        _buildTextField("Luogo", luogoController),
        Row(
          children: [
            Expanded(
              child: _dataSelector(
                "Data da",
                dataDa,
                () => _selezionaData(context, true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dataSelector(
                "Data a",
                dataA,
                () => _selezionaData(context, false),
              ),
            ),
          ],
        ),
        _buildOrariGiornate(),
        _buildDropdownDsc(),
        _buildDropdownElaborazioneDati(),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdownSport() {
    final sportList = [
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
    final items = sportList
        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
        .toList();
    if (sport.isNotEmpty && !sportList.contains(sport)) {
      items.insert(0, DropdownMenuItem(value: sport, child: Text(sport)));
    }
    final dropdownValue = sport.isNotEmpty ? sport : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: dropdownValue,
        items: items,
        onChanged: (val) {
          setState(() => sport = val ?? '');
          if (val != null) {
            widget.onSportChanged?.call(val);
          }
        },
        decoration: const InputDecoration(
          labelText: 'Sport',
          border: OutlineInputBorder(),
        ),
        isExpanded: true,
      ),
    );
  }

  Widget _buildDropdownDsc() {
    final options = availableCronometristi;
    final items = options
        .map((nome) => DropdownMenuItem(value: nome, child: Text(nome)))
        .toList();
    final currentDsc = dscController.text;
    if (currentDsc.isNotEmpty && !options.contains(currentDsc)) {
      items.insert(
        0,
        DropdownMenuItem(value: currentDsc, child: Text(currentDsc)),
      );
    }
    final dropdownValue = currentDsc.isNotEmpty ? currentDsc : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: dropdownValue,
        items: items,
        onChanged: (val) => setState(() => dscController.text = val ?? ''),
        decoration: const InputDecoration(
          labelText: 'DSC',
          border: OutlineInputBorder(),
        ),
        isExpanded: true,
      ),
    );
  }

  Widget _buildDropdownElaborazioneDati() {
    final options = availableCronometristi;
    final items = options
        .map((nome) => DropdownMenuItem(value: nome, child: Text(nome)))
        .toList();
    final current = elaborazioneDatiController.text;
    if (current.isNotEmpty && !options.contains(current)) {
      items.insert(0, DropdownMenuItem(value: current, child: Text(current)));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('elaborazione-dati-$current'),
        initialValue: current.isEmpty ? null : current,
        items: items,
        onChanged: (value) {
          setState(() => elaborazioneDatiController.text = value ?? '');
          widget.onElaborazioneDatiChanged?.call(value);
        },
        decoration: const InputDecoration(
          labelText: 'Elaborazione Dati',
          border: OutlineInputBorder(),
        ),
        isExpanded: true,
      ),
    );
  }

  Widget _buildOrariGiornate() {
    if (orariPerData.isEmpty) return const SizedBox.shrink();
    final giorni = orariPerData.keys.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orari giornate',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Aggiungi ora di inizio, fine ed eventuale pausa.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
          ),
          const SizedBox(height: 12),
          Column(
            children: giorni.map((data) {
              final orari = orariPerData[data] ?? {};
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDateLabel(data),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _timeSelectors(
                      data: data,
                      orari: orari,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.free_breakfast_outlined,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pausa effettuata',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Impostazione valida per la giornata',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            key: ValueKey('break-switch-$data'),
                            value: (orari['pausa'] ?? 'false') == 'true',
                            onChanged: (value) async {
                              _aggiornaOrarioPerData(
                                data,
                                'pausa',
                                value.toString(),
                              );
                              if (value) {
                                await _selectBreakDuration(data);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if ((orari['pausa'] ?? 'false') == 'true') ...[
                      const SizedBox(height: 10),
                      _selectorField(
                        fieldKey: ValueKey('break-selector-$data'),
                        label: 'Durata pausa',
                        value: _formatBreakDuration(orari),
                        icon: Icons.timer_outlined,
                        onTap: () => _selectBreakDuration(data),
                        colorScheme: colorScheme,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _timeSelectors({
    required String data,
    required Map<String, String> orari,
    required ColorScheme colorScheme,
  }) {
    final start = _selectorField(
      fieldKey: ValueKey('time-selector-oraDa-$data'),
      label: 'Ora inizio',
      value: (orari['oraDa'] ?? '').toString(),
      icon: Icons.play_circle_outline_rounded,
      onTap: () => _selectClockTime(data, 'oraDa', 'Ora inizio'),
      colorScheme: colorScheme,
    );
    final end = _selectorField(
      fieldKey: ValueKey('time-selector-oraA-$data'),
      label: 'Ora fine',
      value: (orari['oraA'] ?? '').toString(),
      icon: Icons.stop_circle_outlined,
      onTap: () => _selectClockTime(data, 'oraA', 'Ora fine'),
      colorScheme: colorScheme,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [start, const SizedBox(height: 10), end],
          );
        }
        return Row(
          children: [
            Expanded(child: start),
            const SizedBox(width: 10),
            Expanded(child: end),
          ],
        );
      },
    );
  }

  Widget _selectorField({
    required Key fieldKey,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return Material(
      key: fieldKey,
      color: colorScheme.surface.withOpacity(0.95),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withOpacity(0.45)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? value : 'Seleziona',
                      style: TextStyle(
                        color: hasValue
                            ? colorScheme.onSurface
                            : colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectClockTime(
    String data,
    String campo,
    String title,
  ) async {
    final orari = orariPerData[data] ?? const {};
    final current = _parseTime(orari[campo] ?? '');
    _TimeSelection fallback;
    if (campo == 'oraA') {
      final start = _parseTime(orari['oraDa'] ?? '');
      fallback = start == null
          ? const _TimeSelection(17, 0)
          : _TimeSelection((start.hour + 8) % 24, _nearestFive(start.minute));
    } else {
      fallback = const _TimeSelection(8, 0);
    }

    final selected = await _showTimeSelectionDialog(
      title: title,
      subtitle: 'Scegli ora e minuti a intervalli di 5 minuti.',
      initial: current ?? fallback,
      allowClear: current != null,
    );
    if (selected == null || !mounted) return;
    _aggiornaOrarioPerData(
      data,
      campo,
      selected.clear ? '' : selected.asClockValue,
    );
  }

  Future<void> _selectBreakDuration(String data) async {
    final orari = orariPerData[data] ?? const {};
    final hours = int.tryParse(orari['pausaOre'] ?? '');
    final minutes = int.tryParse(orari['pausaMinuti'] ?? '');
    final hasDuration = hours != null || minutes != null;
    final selected = await _showTimeSelectionDialog(
      title: 'Durata pausa',
      subtitle: 'Scegli la durata a intervalli di 5 minuti.',
      initial: _TimeSelection(
        (hours ?? 0).clamp(0, 12).toInt(),
        _nearestFive((minutes ?? 30).clamp(0, 59).toInt()),
      ),
      maxHour: 12,
      allowClear: hasDuration,
      durationMode: true,
    );
    if (selected == null || !mounted) return;
    _aggiornaCampiPerData(data, {
      'pausaOre': selected.clear ? '' : selected.hour.toString(),
      'pausaMinuti': selected.clear ? '' : selected.minute.toString(),
    });
  }

  Future<_TimeSelection?> _showTimeSelectionDialog({
    required String title,
    required String subtitle,
    required _TimeSelection initial,
    int maxHour = 23,
    bool allowClear = false,
    bool durationMode = false,
  }) {
    var selectedHour = initial.hour.clamp(0, maxHour).toInt();
    var selectedMinute = _nearestFive(initial.minute);
    return showDialog<_TimeSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            durationMode ? Icons.timer_outlined : Icons.schedule_rounded,
          ),
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('hour-dropdown'),
                        initialValue: selectedHour,
                        decoration: InputDecoration(
                          labelText: durationMode ? 'Ore' : 'Ora',
                          border: const OutlineInputBorder(),
                        ),
                        items: List.generate(
                          maxHour + 1,
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text(hour.toString().padLeft(2, '0')),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedHour = value);
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        ':',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('minute-dropdown'),
                        initialValue: selectedMinute,
                        decoration: const InputDecoration(
                          labelText: 'Minuti',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(
                          12,
                          (index) {
                            final minute = index * 5;
                            return DropdownMenuItem(
                              value: minute,
                              child: Text(minute.toString().padLeft(2, '0')),
                            );
                          },
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedMinute = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (allowClear)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  const _TimeSelection.clear(),
                ),
                child: const Text('Cancella valore'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton.icon(
              key: const ValueKey('confirm-time-selection'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _TimeSelection(selectedHour, selectedMinute),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );
  }

  int _nearestFive(int minute) {
    final rounded = ((minute / 5).round() * 5);
    return rounded > 55 ? 55 : rounded;
  }

  String _formatBreakDuration(Map<String, String> orari) {
    final hours = int.tryParse(orari['pausaOre'] ?? '') ?? 0;
    final minutes = int.tryParse(orari['pausaMinuti'] ?? '') ?? 0;
    if (hours <= 0 && minutes <= 0) return 'Seleziona';
    final parts = <String>[];
    if (hours > 0) parts.add('$hours h');
    if (minutes > 0) parts.add('$minutes min');
    return parts.join(' ');
  }

  String _formatDateLabel(dynamic value) {
    final d = value?.toString() ?? '';
    if (d.isEmpty) return '';
    return formatItalianIsoDateOrValue(d, emptyValue: '');
  }

  Widget _dataSelector(String label, DateTime? date, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextButton(
          onPressed: onPressed,
          child: Text(
            date == null
                ? 'Seleziona'
                : "${date.day}/${date.month}/${date.year}",
          ),
        ),
      ],
    );
  }
}

class _TimeSelection {
  final int hour;
  final int minute;
  final bool clear;

  const _TimeSelection(this.hour, this.minute) : clear = false;
  const _TimeSelection.clear()
      : hour = 0,
        minute = 0,
        clear = true;

  String get asClockValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
