import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';

class GaraForm extends StatefulWidget {
  final ValueChanged<String>? onSportChanged;
  final void Function(DateTime?, DateTime?)? onDateRangeChanged;
  const GaraForm({Key? key, this.onSportChanged, this.onDateRangeChanged})
      : super(key: key);

  @override
  GaraFormState createState() => GaraFormState();
}

class GaraFormState extends State<GaraForm> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController organizzatoreController =
      TextEditingController();
  final TextEditingController luogoController = TextEditingController();
  final TextEditingController dscController = TextEditingController();
  String sport = '';
  DateTime? dataDa;
  DateTime? dataA;

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
        });
        widget.onDateRangeChanged?.call(dataDa, dataA);
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
      if (dsc != null) {
        dscController.text = dsc;
      }
    });
    widget.onSportChanged?.call(sport);
    widget.onDateRangeChanged?.call(dataDa, dataA);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Informazioni Gara",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _buildTextField("Nome Gara", nomeController),
        _buildTextField("Organizzatore", organizzatoreController),
        _buildDropdownSport(),
        _buildTextField("Luogo", luogoController),
        Row(
          children: [
            Expanded(
                child: _dataSelector(
                    "Data da", dataDa, () => _selezionaData(context, true))),
            const SizedBox(width: 8),
            Expanded(
                child: _dataSelector(
                    "Data a", dataA, () => _selezionaData(context, false))),
          ],
        ),
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
      'Corsa in montagna',
      'Hockey ghiaccio',
      'Nuoto',
      'Rally',
      'Regolarità auto',
      'Regolarità storiche',
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
      items.insert(
        0,
        DropdownMenuItem(
          value: sport,
          child: Text(sport),
        ),
      );
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
        DropdownMenuItem(
          value: currentDsc,
          child: Text(currentDsc),
        ),
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

  Widget _dataSelector(String label, DateTime? date, VoidCallback onPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        TextButton(
          onPressed: onPressed,
          child: Text(date == null
              ? 'Seleziona'
              : "${date.day}/${date.month}/${date.year}"),
        ),
      ],
    );
  }
}
