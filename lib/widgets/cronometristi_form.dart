import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';

class CronometristiForm extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const CronometristiForm({super.key, this.onDataChanged});

  @override
  CronometristiFormState createState() => CronometristiFormState();
}

class CronometristiFormState extends State<CronometristiForm> {
  int _revision = 0;
  DateTime? _rangeDa;
  DateTime? _rangeA;
  final List<String> cronometristiDisponibili =
      List<String>.from(availableCronometristi);
  Map<String, Map<String, String>> orariPerData = {};

  List<Map<String, dynamic>> righe = [
    {
      'nome': null,
      'giorni': [
        {'ore': '', 'km': '', 'spese': '', 'oraDa': '', 'oraA': ''}
      ],
      'segreteria': null,
      'note': '',
    }
  ];

  List<Map<String, dynamic>> getData() => righe;
  Map<String, Map<String, String>> getOrariGiornata() =>
      Map<String, Map<String, String>>.from(orariPerData);

  void _notifyDataChanged() {
    widget.onDataChanged?.call();
  }

  // Sincronizza i giorni con l'intervallo [da, a] impostato nella sezione gara.
  // Crea un elemento per ciascun giorno calendario e preserva i valori esistenti per indice.
  void syncDaysWithRange(DateTime? da, DateTime? a) {
    if (da == null || a == null) return;
    if (a.isBefore(da)) return;
    final total = a.difference(da).inDays + 1;
    final Map<String, Map<String, String>> nuoviOrari = {};
    for (int i = 0; i < total; i++) {
      final date = DateTime(da.year, da.month, da.day).add(Duration(days: i));
      final iso =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final esistente = orariPerData[iso] ?? {};
      nuoviOrari[iso] = {
        'oraDa': (esistente['oraDa'] ?? '').toString(),
        'oraA': (esistente['oraA'] ?? '').toString(),
      };
    }
    setState(() {
      _rangeDa = da;
      _rangeA = a;
      orariPerData = nuoviOrari;
      for (final riga in righe) {
        final List<dynamic> cur = List<dynamic>.from(riga['giorni'] ?? []);
        final List<Map<String, dynamic>> nuovo = [];
        for (int i = 0; i < total; i++) {
          final date =
              DateTime(da.year, da.month, da.day).add(Duration(days: i));
          final iso =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          final existing = (i < cur.length) ? cur[i] : <String, dynamic>{};
          nuovo.add({
            'data': iso,
            'ore': existing['ore'] ?? '',
            'km': existing['km'] ?? '',
            'spese': existing['spese'] ?? '',
            'oraDa': orariPerData[iso]?['oraDa'] ?? '',
            'oraA': orariPerData[iso]?['oraA'] ?? '',
          });
        }
        riga['giorni'] = nuovo;
      }
    });
    _notifyDataChanged();
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
    _notifyDataChanged();
  }

  List<Map<String, dynamic>> _giorniPerRange() {
    if (_rangeDa != null && _rangeA != null && !_rangeA!.isBefore(_rangeDa!)) {
      final total = _rangeA!.difference(_rangeDa!).inDays + 1;
      return List.generate(total, (index) {
        final d = DateTime(_rangeDa!.year, _rangeDa!.month, _rangeDa!.day)
            .add(Duration(days: index));
        final iso =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        final orari = orariPerData[iso] ?? {};
        return {
          'data': iso,
          'ore': '',
          'km': '',
          'spese': '',
          'oraDa': (orari['oraDa'] ?? '').toString(),
          'oraA': (orari['oraA'] ?? '').toString(),
        };
      });
    }
    return [
      {'ore': '', 'km': '', 'spese': '', 'oraDa': '', 'oraA': ''}
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
    _notifyDataChanged();
  }

  void setOrari(Map<String, Map<String, String>> orari) {
    setState(() {
      orariPerData = Map<String, Map<String, String>>.from(orari);
      for (final riga in righe) {
        final giorni = (riga['giorni'] as List?) ?? [];
        for (final g in giorni) {
          final data = (g['data'] ?? '').toString();
          final orariData = orariPerData[data] ?? {};
          g['oraDa'] = (orariData['oraDa'] ?? '').toString();
          g['oraA'] = (orariData['oraA'] ?? '').toString();
        }
      }
    });
    _notifyDataChanged();
  }

  void applySavedData(List<dynamic> savedRows) {
    Map<String, dynamic> normalizeDay(dynamic raw) {
      if (raw is! Map) {
        return {
          'data': '',
          'ore': '',
          'km': '',
          'spese': '',
          'oraDa': '',
          'oraA': '',
        };
      }
      return {
        'data': (raw['data'] ?? '').toString(),
        'ore': (raw['ore'] ?? '').toString(),
        'km': (raw['km'] ?? '').toString(),
        'spese': (raw['spese'] ?? '').toString(),
        'oraDa': (raw['oraDa'] ?? '').toString(),
        'oraA': (raw['oraA'] ?? '').toString(),
      };
    }

    Map<String, dynamic> normalizeRow(dynamic raw) {
      if (raw is! Map) {
        return {
          'nome': null,
          'giorni': _giorniPerRange(),
          'segreteria': null,
          'note': '',
        };
      }
      final giorni = (raw['giorni'] as List? ?? const [])
          .map<Map<String, dynamic>>(normalizeDay)
          .toList();
      return {
        'nome': raw['nome'],
        'giorni': giorni,
        'segreteria': raw['segreteria'],
        'note': (raw['note'] ?? '').toString(),
      };
    }

    setState(() {
      final rows = savedRows.map<Map<String, dynamic>>(normalizeRow).toList();
      righe = rows.isEmpty
          ? [
              {
                'nome': null,
                'giorni': _giorniPerRange(),
                'segreteria': null,
                'note': '',
              }
            ]
          : rows;
      _revision++;
    });
    _notifyDataChanged();
  }

  void rimuoviRiga(int index) {
    setState(() {
      righe.removeAt(index);
    });
    _notifyDataChanged();
  }

  void aggiungiGiorno(Map<String, dynamic> riga) {
    if ((riga['giorni'] as List).length >= 10) return;
    setState(() {
      (riga['giorni'] as List)
          .add({'ore': '', 'km': '', 'spese': '', 'oraDa': '', 'oraA': ''});
    });
    _notifyDataChanged();
  }

  void rimuoviGiorno(Map<String, dynamic> riga, int giornoIndex) {
    setState(() {
      (riga['giorni'] as List).removeAt(giornoIndex);
    });
    _notifyDataChanged();
  }

  Widget _giornoTile({
    required Map<String, dynamic> giorno,
    required int index,
    required Function(String, String) onUpdate,
    required VoidCallback onRemove,
    required ColorScheme colorScheme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 18, color: colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                _formatDateLabel(giorno['data'], index: index),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: colorScheme.onSurface.withOpacity(0.6),
                onPressed: onRemove,
                tooltip: 'Rimuovi questo giorno',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniField(
                  fieldKey: ValueKey('ore-$_revision-$index'),
                  hint: 'Ore',
                  initialValue: (giorno['ore'] ?? '').toString(),
                  prefix: 'Ore',
                  onChanged: (val) => onUpdate('ore', val),
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(
                  fieldKey: ValueKey('km-$_revision-$index'),
                  hint: 'Km',
                  initialValue: (giorno['km'] ?? '').toString(),
                  prefix: 'Km',
                  onChanged: (val) => onUpdate('km', val),
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(
                  fieldKey: ValueKey('spese-$_revision-$index'),
                  hint: 'EUR',
                  initialValue: (giorno['spese'] ?? '').toString(),
                  prefix: 'EUR',
                  onChanged: (val) => onUpdate('spese', val),
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniField({
    required Key fieldKey,
    required String hint,
    required String initialValue,
    required String prefix,
    required ValueChanged<String> onChanged,
    required ColorScheme colorScheme,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? colorScheme.surface.withOpacity(0.25)
        : colorScheme.surface.withOpacity(0.9);
    final outline = colorScheme.outline.withOpacity(0.6);

    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: prefix,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.85),
          fontWeight: FontWeight.w700,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _totalPill(String label, num value, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            "$label: $value",
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
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

  String _formatDateLabel(dynamic value, {int? index}) {
    final d = value?.toString() ?? '';
    if (d.isEmpty) return index != null ? "Giorno ${index + 1}: " : '';
    final parts = d.split('-');
    if (parts.length == 3) {
      final dd = parts[2].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      final yyyy = parts[0];
      return "$dd/$mm/$yyyy";
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Cronometristi", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          "Ore, km e spese per cronometrista, per giornata.",
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
            final giorni = (riga['giorni'] as List?)?.cast<Map>() ?? <Map>[];
            final nomeCorrente = riga['nome'];
            final voci = Set<String>.from(cronometristiDisponibili);
            if (nomeCorrente != null) voci.add(nomeCorrente);

            final totali = calcolaTotali(giorni);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('cronometrista-$_revision-$index'),
                          initialValue: nomeCorrente,
                          items: voci
                              .map((nome) => DropdownMenuItem(
                                  value: nome,
                                  child: Text(nome,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          isExpanded: true,
                          onChanged: (val) => setState(() {
                            riga['nome'] = val;
                            _notifyDataChanged();
                          }),
                          decoration: InputDecoration(
                            labelText: 'Cronometrista',
                            filled: true,
                            fillColor: colorScheme.surface.withOpacity(0.95),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (righe.length > 1)
                        IconButton(
                          onPressed: () => rimuoviRiga(index),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Rimuovi questo cronometrista',
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: List.generate(giorni.length, (g) {
                      return _giornoTile(
                        giorno: giorni[g] as Map<String, dynamic>,
                        index: g,
                        onUpdate: (campo, val) => setState(() {
                          (giorni[g])[campo] = val;
                          _notifyDataChanged();
                        }),
                        onRemove: () => rimuoviGiorno(riga, g),
                        colorScheme: colorScheme,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _totalPill(
                          'Ore', totali['ore'] ?? 0, Icons.timer, colorScheme),
                      _totalPill('Km', totali['km'] ?? 0,
                          Icons.directions_car_rounded, colorScheme),
                      _totalPill('Spese', totali['spese'] ?? 0,
                          Icons.account_balance_wallet_rounded, colorScheme),
                    ],
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
                                onChanged: (val) => setState(() {
                                  riga['segreteria'] = val;
                                  _notifyDataChanged();
                                }),
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('NO'),
                                value: 'NO',
                                groupValue: riga['segreteria'],
                                onChanged: (val) => setState(() {
                                  riga['segreteria'] = val;
                                  _notifyDataChanged();
                                }),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: ValueKey('note-$_revision-$index'),
                    initialValue: riga['note'],
                    onChanged: (val) {
                      riga['note'] = val;
                      _notifyDataChanged();
                    },
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Varie / Note',
                      filled: true,
                      fillColor: colorScheme.surface.withOpacity(0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
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
