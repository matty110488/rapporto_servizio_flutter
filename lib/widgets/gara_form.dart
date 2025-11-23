import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';

class GaraForm extends StatefulWidget {
  final ValueChanged<String>? onSportChanged;
  final void Function(DateTime?, DateTime?)? onDateRangeChanged;
  final ValueChanged<Map<String, Map<String, String>>>? onOrariChanged;
  const GaraForm({
    Key? key,
    this.onSportChanged,
    this.onDateRangeChanged,
    this.onOrariChanged,
  }) : super(key: key);

  @override
  GaraFormState createState() => GaraFormState();
}

class GaraFormState extends State<GaraForm> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController organizzatoreController = TextEditingController();
  final TextEditingController luogoController = TextEditingController();
  final TextEditingController dscController = TextEditingController();
  String sport = '';
  DateTime? dataDa;
  DateTime? dataA;
  Map<String, Map<String, String>> orariPerData = {};

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
      'dsc': dscController.text,
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
      };
    }
    orariPerData = updated;
  }

  void _aggiornaOrarioPerData(String data, String campo, String valore) {
    setState(() {
      final corrente = Map<String, String>.from(orariPerData[data] ?? {});
      corrente[campo] = valore;
      orariPerData[data] = {
        'oraDa': (corrente['oraDa'] ?? '').toString(),
        'oraA': (corrente['oraA'] ?? '').toString(),
      };
    });
    widget.onOrariChanged?.call(getOrariGiornata());
  }

  void applyNotionData({
    required String nome,
    required String organizzatore,
    required String sportValue,
    required String luogo,
    required String dataInizio,
    required String dataFine,
    String? dsc,
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
        dscController.text = dsc;
      }
    });
    widget.onSportChanged?.call(sport);
    widget.onDateRangeChanged?.call(dataDa, dataA);
    widget.onOrariChanged?.call(getOrariGiornata());
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
      'Ciclismo su strada',
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
        value: dropdownValue,
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
        value: dropdownValue,
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
            'Aggiungi ora inizio e fine.',
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
                  color: colorScheme.surfaceVariant.withOpacity(0.35),
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
                    Row(
                      children: [
                        Expanded(
                          child: _timeField(
                            label: 'Ora inizio',
                            hint: 'HH:MM',
                            initialValue: orari['oraDa'] ?? '',
                            onChanged: (val) =>
                                _aggiornaOrarioPerData(data, 'oraDa', val),
                            fieldKey: ValueKey('ora-da-gara-$data'),
                            colorScheme: colorScheme,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _timeField(
                            label: 'Ora fine',
                            hint: 'HH:MM',
                            initialValue: orari['oraA'] ?? '',
                            onChanged: (val) =>
                                _aggiornaOrarioPerData(data, 'oraA', val),
                            fieldKey: ValueKey('ora-a-gara-$data'),
                            colorScheme: colorScheme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _timeField({
    required String label,
    required String hint,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required Key fieldKey,
    required ColorScheme colorScheme,
  }) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(Icons.schedule_rounded,
            size: 18, color: colorScheme.primary.withOpacity(0.8)),
        filled: true,
        fillColor: colorScheme.surface.withOpacity(0.95),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      keyboardType: TextInputType.datetime,
      onChanged: onChanged,
    );
  }

  String _formatDateLabel(dynamic value) {
    final d = value?.toString() ?? '';
    if (d.isEmpty) return '';
    final parts = d.split('-');
    if (parts.length == 3) {
      final dd = parts[2].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      final yyyy = parts[0];
      return "$dd/$mm/$yyyy";
    }
    return d;
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
