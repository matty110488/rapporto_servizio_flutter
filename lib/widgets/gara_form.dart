import 'package:flutter/material.dart';

class GaraForm extends StatefulWidget {
  final ValueChanged<String>? onSportChanged;
  final void Function(DateTime?, DateTime?)? onDateRangeChanged;
  const GaraForm({Key? key, this.onSportChanged, this.onDateRangeChanged})
      : super(key: key);

  @override
  GaraFormState createState() => GaraFormState();
}

class GaraFormState extends State<GaraForm> {
  String nomeGara = '';
  String organizzatore = '';
  String sport = '';
  String luogo = '';
  DateTime? dataDa;
  DateTime? dataA;
  /* String altro = '';*/

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
      'nome': nomeGara,
      'organizzatore': organizzatore,
      'sport': sport,
      'luogo': luogo,
      'dataDa': dataDa != null
          ? "${dataDa!.year}-${_2(dataDa!.month)}-${_2(dataDa!.day)}"
          : '',
      'dataA': dataA != null
          ? "${dataA!.year}-${_2(dataA!.month)}-${_2(dataA!.day)}"
          : '',
      /*   'altro': altro,*/
    };
  }

  String _2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Informazioni Gara",
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _buildTextField("Nome Gara", (val) => nomeGara = val),
        _buildTextField("Organizzatore", (val) => organizzatore = val),
        _buildDropdownSport(),
        _buildTextField("Luogo", (val) => luogo = val),
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
        /*   _buildTextField("Altro (specificare)", (val) => altro = val),*/
      ],
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: sport.isEmpty ? null : sport,
        items: sportList
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
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
