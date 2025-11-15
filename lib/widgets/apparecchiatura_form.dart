import 'package:flutter/material.dart';

class ApparecchiaturaForm extends StatefulWidget {
  const ApparecchiaturaForm({Key? key}) : super(key: key);

  @override
  ApparecchiaturaFormState createState() => ApparecchiaturaFormState();
}

class ApparecchiaturaFormState extends State<ApparecchiaturaForm> {
  final List<String> dispositiviDisponibili = [
    '*** CRONOMETRI ***',
    'Rei Pro',
    'Rei 2',
    'Master 3',
    'Master',
    'Timy',
    '*** TABELLONI ***',
    'Alge',
    'MicroTab',
    'MicroGraph',
    'Semaforo',
    'Hiclock',
    'StartClock',
    '*** ALTRO ***',
    'Cancelletto',
    'Fotocellula',
    'StartBeep',
    'Cuffie',
    'Chip Machsa',
    'Pressostato',
    'Smartphone',
  ];

  List<Map<String, dynamic>> righe = [
    {'dispositivo': null, 'quantita': ''}
  ];

  List<Map<String, dynamic>> getData() => righe;

  void aggiungiRiga() {
    setState(() {
      righe.add({'dispositivo': null, 'quantita': ''});
    });
  }

  void rimuoviRiga(int index) {
    setState(() {
      if (righe.length > 1) {
        righe.removeAt(index);
      } else {
        righe[0]['dispositivo'] = null;
        righe[0]['quantita'] = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Apparecchiatura", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: righe.length,
          itemBuilder: (context, index) {
            final riga = righe[index];
            final opzioni = dispositiviDisponibili
                .where((d) => !d.startsWith('***'))
                .toList();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: riga['dispositivo'],
                        items: opzioni
                            .where((d) =>
                                !righe.any((r) => r['dispositivo'] == d) ||
                                riga['dispositivo'] == d)
                            .map((d) => DropdownMenuItem(
                                value: d,
                                child:
                                    Text(d, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        isExpanded: true,
                        onChanged: (val) =>
                            setState(() => riga['dispositivo'] = val),
                        decoration: const InputDecoration(
                          labelText: 'Dispositivo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: riga['quantita'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantita',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                        onChanged: (val) => riga['quantita'] = val,
                      ),
                    ),
                    (((riga['dispositivo'] ?? '').toString().isNotEmpty) ||
                            ((riga['quantita'] ?? '').toString().isNotEmpty))
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            onPressed: () => rimuoviRiga(index),
                            tooltip: 'Rimuovi questo dispositivo',
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: aggiungiRiga,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi dispositivo'),
        ),
      ],
    );
  }
}
