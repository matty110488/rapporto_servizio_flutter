import 'package:flutter/material.dart';

class ApparecchiaturaForm extends StatefulWidget {
  final bool isFisSport;
  final String tipoGara;

  const ApparecchiaturaForm({
    super.key,
    this.isFisSport = false,
    this.tipoGara = '',
  });

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

  String tabelloneFis = 'NO';
  String giornateSegreteria = '';

  @override
  void didUpdateWidget(covariant ApparecchiaturaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFisSport != widget.isFisSport) {
      setState(() {
        righe = [
          {'dispositivo': null, 'quantita': ''}
        ];
        tabelloneFis = 'NO';
        giornateSegreteria = '';
      });
    }
  }

  List<Map<String, dynamic>> getData() {
    if (widget.isFisSport) {
      return [
        {
          'dispositivo': 'TABELLONE',
          'quantita': tabelloneFis,
          'giornateSegreteria': giornateSegreteria,
          'fisMode': true,
          'tipoGara': widget.tipoGara,
        }
      ];
    }
    return righe;
  }

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

  void _showSegreteriaInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Numero giornate segreteria'),
        content: const Text('Giornate di gara + giornate di preparazione gara'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.72),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.isFisSport) {
      final tipoGaraLabel =
          widget.tipoGara.trim().isEmpty ? 'N/D' : widget.tipoGara.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: "Apparecchiatura per gara $tipoGaraLabel",
            subtitle: "Compila i dati di segreteria e presenza tabellone.",
            icon: Icons.precision_manufacturing_rounded,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outline.withOpacity(0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: giornateSegreteria,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(() => giornateSegreteria = val),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Numero giornate segreteria',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Informazioni',
                      icon: const Icon(Icons.help_outline_rounded),
                      onPressed: _showSegreteriaInfoDialog,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colorScheme.outline.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TABELLONE',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('SI'),
                              value: 'SI',
                              groupValue: tabelloneFis,
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => tabelloneFis = val);
                              },
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('NO'),
                              value: 'NO',
                              groupValue: tabelloneFis,
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => tabelloneFis = val);
                              },
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: "Apparecchiatura",
          subtitle: "Indica i dispositivi utilizzati in gara e la quantita.",
          icon: Icons.handyman_rounded,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          "Dispositivo ${index + 1}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      (((riga['dispositivo'] ?? '').toString().isNotEmpty) ||
                              ((riga['quantita'] ?? '').toString().isNotEmpty))
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
                  DropdownButtonFormField<String>(
                    initialValue: riga['dispositivo'],
                    items: opzioni
                        .where((d) =>
                            !righe.any((r) => r['dispositivo'] == d) ||
                            riga['dispositivo'] == d)
                        .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    isExpanded: true,
                    onChanged: (val) =>
                        setState(() => riga['dispositivo'] = val),
                    decoration: InputDecoration(
                      labelText: 'Dispositivo',
                      filled: true,
                      fillColor: colorScheme.surface.withOpacity(0.95),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 170,
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
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: aggiungiRiga,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi dispositivo'),
          ),
        ),
      ],
    );
  }
}
