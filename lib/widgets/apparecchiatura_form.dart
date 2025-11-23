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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Apparecchiatura", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Apparecchiatura utilizzata in gara.",
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
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
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: riga['dispositivo'],
                              items: opzioni
                                  .where((d) =>
                                      !righe
                                          .any((r) => r['dispositivo'] == d) ||
                                      riga['dispositivo'] == d)
                                  .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              isExpanded: true,
                              onChanged: (val) =>
                                  setState(() => riga['dispositivo'] = val),
                              decoration: InputDecoration(
                                labelText: 'Dispositivo',
                                filled: true,
                                fillColor:
                                    colorScheme.surface.withOpacity(0.95),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          (((riga['dispositivo'] ?? '')
                                      .toString()
                                      .isNotEmpty) ||
                                  ((riga['quantita'] ?? '')
                                      .toString()
                                      .isNotEmpty))
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  onPressed: () => rimuoviRiga(index),
                                  tooltip: 'Rimuovi questo dispositivo',
                                )
                              : const SizedBox(width: 8),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 160,
                        child: TextFormField(
                          initialValue: riga['quantita'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantita',
                            hintText: 'Es. 2',
                            prefixIcon: Icon(Icons.numbers_rounded,
                                size: 18,
                                color: colorScheme.primary.withOpacity(0.8)),
                            filled: true,
                            fillColor: colorScheme.surface.withOpacity(0.95),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (val) => riga['quantita'] = val,
                        ),
                      ),
                    ],
                  ),
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
