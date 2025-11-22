import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';

class CronometristiForm extends StatefulWidget {
  const CronometristiForm({Key? key}) : super(key: key);

  @override
  CronometristiFormState createState() => CronometristiFormState();
}

class CronometristiFormState extends State<CronometristiForm> {
  DateTime? _rangeDa;
  DateTime? _rangeA;
  final List<String> cronometristiDisponibili =
      List<String>.from(availableCronometristi);

  List<Map<String, dynamic>> righe = [
    {
      'nome': null,
      'giorni': [
        {'ore': '', 'km': '', 'spese': ''}
      ],
      'segreteria': null,
      'note': '',
    }
  ];

  List<Map<String, dynamic>> getData() => righe;

  // Sincronizza i giorni con l'intervallo [da, a] impostato nella sezione gara.
  // Crea un elemento per ciascun giorno calendario e preserva i valori esistenti per indice.
  void syncDaysWithRange(DateTime? da, DateTime? a) {
    if (da == null || a == null) return;
    if (a.isBefore(da)) return;
    final total = a.difference(da).inDays + 1;
    setState(() {
      _rangeDa = da;
      _rangeA = a;
      for (final riga in righe) {
        final List<dynamic> cur = List<dynamic>.from(riga['giorni'] ?? []);
        final List<Map<String, dynamic>> nuovo = [];
        for (int i = 0; i < total; i++) {
          final date =
              DateTime(da.year, da.month, da.day).add(Duration(days: i));
          final existing = (i < cur.length) ? cur[i] : <String, dynamic>{};
          nuovo.add({
            'data':
                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
            'ore': existing['ore'] ?? '',
            'km': existing['km'] ?? '',
            'spese': existing['spese'] ?? '',
          });
        }
        riga['giorni'] = nuovo;
      }
    });
  }

  void aggiungiRiga() {
    setState(() {
      final giorni = _giorniPerRange();
      righe.add({
        'nome': null,
        'giorni': giorni,
        'segreteria': null,
        'note': '',
      });
    });
  }

  List<Map<String, dynamic>> _giorniPerRange() {
    if (_rangeDa != null && _rangeA != null && !_rangeA!.isBefore(_rangeDa!)) {
      final total = _rangeA!.difference(_rangeDa!).inDays + 1;
      return List.generate(total, (index) {
        final d =
            DateTime(_rangeDa!.year, _rangeDa!.month, _rangeDa!.day)
                .add(Duration(days: index));
        return {
          'data':
              "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}",
          'ore': '',
          'km': '',
          'spese': '',
        };
      });
    }
    return [
      {'ore': '', 'km': '', 'spese': ''}
    ];
  }

  void setCronometristi(List<String> nomi) {
    setState(() {
      if (nomi.isEmpty) {
        righe = [
          {
            'nome': null,
            'giorni': _giorniPerRange(),
            'segreteria': null,
            'note': '',
          }
        ];
      } else {
        righe = nomi
            .map((nome) => {
                  'nome': nome,
                  'giorni': _giorniPerRange(),
                  'segreteria': null,
                  'note': '',
                })
            .toList();
      }
    });
  }

  void rimuoviRiga(int index) {
    setState(() {
      righe.removeAt(index);
    });
  }

  void aggiungiGiorno(Map<String, dynamic> riga) {
    if ((riga['giorni'] as List).length >= 10) return;
    setState(() {
      (riga['giorni'] as List).add({'ore': '', 'km': '', 'spese': ''});
    });
  }

  void rimuoviGiorno(Map<String, dynamic> riga, int giornoIndex) {
    setState(() {
      (riga['giorni'] as List).removeAt(giornoIndex);
    });
  }

  Widget _giornoHeader() {
    Text header(String text) => Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 100, child: Text('Data')),
          const SizedBox(width: 8),
          Expanded(child: header('Ore')),
          const SizedBox(width: 8),
          Expanded(child: header('Km')),
          const SizedBox(width: 8),
          Expanded(child: header('Spese')),
          const SizedBox(width: 40), // spazio per l'icona remove
        ],
      ),
    );
  }

  Widget _campoGiorno(
    Map<String, dynamic> giorno,
    int index,
    Function(String, String) onUpdate,
    VoidCallback onRemove,
  ) {
    String labelData() {
      final d = giorno['data'];
      if (d == null || d.isEmpty) return "Giorno ${index + 1}: ";
      // formato atteso yyyy-MM-dd
      final parts = d.split('-');
      if (parts.length == 3) {
        final dd = parts[2].padLeft(2, '0');
        final mm = parts[1].padLeft(2, '0');
        final yyyy = parts[0];
        return "$dd/$mm/$yyyy";
      }
      return d;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(labelData())),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: (giorno['ore'] ?? '').toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ore',
                hintText: 'Ore',
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              onChanged: (val) => onUpdate('ore', val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: (giorno['km'] ?? '').toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Km',
                hintText: 'Km',
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              onChanged: (val) => onUpdate('km', val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: (giorno['spese'] ?? '').toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Spese',
                hintText: 'Spese',
                floatingLabelBehavior: FloatingLabelBehavior.never,
              ),
              onChanged: (val) => onUpdate('spese', val),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            onPressed: onRemove,
            tooltip: 'Rimuovi questo giorno',
          ),
        ],
      ),
    );
  }

  Map<String, num> calcolaTotali(List<Map> giorni) {
    num oreTot = 0, kmTot = 0, speseTot = 0;
    for (var g in giorni) {
      oreTot += num.tryParse((g['ore'] ?? '').toString()) ?? 0;
      kmTot += num.tryParse((g['km'] ?? '').toString()) ?? 0;
      speseTot += num.tryParse((g['spese'] ?? '').toString()) ?? 0;
    }
    return {'ore': oreTot, 'km': kmTot, 'spese': speseTot};
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Cronometristi", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: righe.length,
          itemBuilder: (context, index) {
            final riga = righe[index];
            final giorni = (riga['giorni'] as List?)?.cast<Map>() ?? <Map>[];
            final nomeCorrente = riga['nome'];
            final voci = Set<String>.from(cronometristiDisponibili);
            if (nomeCorrente != null) voci.add(nomeCorrente);

            final totali = calcolaTotali(giorni);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: nomeCorrente,
                            items: voci
                                .map((nome) => DropdownMenuItem(
                                    value: nome,
                                    child: Text(nome,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            isExpanded: true,
                            onChanged: (val) =>
                                setState(() => riga['nome'] = val),
                            decoration: const InputDecoration(
                              labelText: 'Cronometrista',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (righe.length > 1)
                          IconButton(
                            onPressed: () => rimuoviRiga(index),
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            tooltip: 'Rimuovi questo cronometrista',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (giorni.isNotEmpty) _giornoHeader(),
                    Column(
                      children: List.generate(giorni.length, (g) {
                        return _campoGiorno(
                          giorni[g] as Map<String, dynamic>,
                          g,
                          (campo, val) =>
                              setState(() => (giorni[g] as Map)[campo] = val),
                          () => rimuoviGiorno(riga, g),
                        );
                      }),
                    ),
                    if (_rangeDa == null || _rangeA == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => aggiungiGiorno(riga),
                          icon: const Icon(Icons.add),
                          label: const Text("Aggiungi giorno"),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text("Totale ore: ${totali['ore']}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Totale km: ${totali['km']}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Totale spese: ${totali['spese']}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Segreteria',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('SI'),
                                value: 'SI',
                                groupValue: riga['segreteria'],
                                onChanged: (val) =>
                                    setState(() => riga['segreteria'] = val),
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('NO'),
                                value: 'NO',
                                groupValue: riga['segreteria'],
                                onChanged: (val) =>
                                    setState(() => riga['segreteria'] = val),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: riga['note'],
                      onChanged: (val) => riga['note'] = val,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Varie / Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: aggiungiRiga,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi cronometrista'),
        ),
      ],
    );
  }
}
