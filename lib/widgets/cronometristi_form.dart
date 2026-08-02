import 'package:flutter/material.dart';
import '../constants/cronometristi.dart';
import '../utils/italian_date_formatter.dart';
import '../utils/person_name_formatter.dart';

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
  List<DateTime> _activeDates = [];
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

  List<Map<String, dynamic>> getData() {
    for (final row in righe) {
      final name = row['nome'];
      if (name != null) row['nome'] = formatPersonName(name);
    }
    return righe;
  }

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
    final dates = List.generate(
      total,
      (index) => DateTime(da.year, da.month, da.day).add(Duration(days: index)),
    );
    syncDaysWithDates(dates);
  }

  void syncDaysWithDates(List<DateTime> dates) {
    final uniqueDates = <String, DateTime>{};
    for (final rawDate in dates) {
      final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
      uniqueDates[_isoDate(date)] = date;
    }
    final orderedDates = uniqueDates.values.toList()..sort();
    final Map<String, Map<String, String>> nuoviOrari = {};
    for (final date in orderedDates) {
      final iso = _isoDate(date);
      final esistente = orariPerData[iso] ?? {};
      nuoviOrari[iso] = {
        'oraDa': (esistente['oraDa'] ?? '').toString(),
        'oraA': (esistente['oraA'] ?? '').toString(),
        'pausa': (esistente['pausa'] ?? 'false').toString(),
        'pausaOre': (esistente['pausaOre'] ?? '').toString(),
        'pausaMinuti': (esistente['pausaMinuti'] ?? '').toString(),
      };
    }
    setState(() {
      _activeDates = orderedDates;
      _rangeDa = orderedDates.isEmpty ? null : orderedDates.first;
      _rangeA = orderedDates.isEmpty ? null : orderedDates.last;
      orariPerData = nuoviOrari;
      for (final riga in righe) {
        final List<dynamic> cur = List<dynamic>.from(riga['giorni'] ?? []);
        final existingByDate = <String, Map>{};
        for (final raw in cur.whereType<Map>()) {
          final date = (raw['data'] ?? '').toString();
          if (date.isNotEmpty) existingByDate[date] = raw;
        }
        final List<Map<String, dynamic>> nuovo = [];
        for (var index = 0; index < orderedDates.length; index++) {
          final iso = _isoDate(orderedDates[index]);
          final indexed = index < cur.length ? cur[index] : null;
          final existing =
              existingByDate[iso] ?? (indexed is Map ? indexed : const {});
          final giorno = {
            'data': iso,
            'ore': existing['ore'] ?? '',
            'km': existing['km'] ?? '',
            'spese': existing['spese'] ?? '',
            'oraDa': orariPerData[iso]?['oraDa'] ?? '',
            'oraA': orariPerData[iso]?['oraA'] ?? '',
            'pausa': orariPerData[iso]?['pausa'] ?? 'false',
            'pausaOre': orariPerData[iso]?['pausaOre'] ?? '',
            'pausaMinuti': orariPerData[iso]?['pausaMinuti'] ?? '',
          };
          if ((giorno['ore'] ?? '').toString().isEmpty) {
            giorno['ore'] = _calcolaOre(orariPerData[iso] ?? const {}) ?? '';
          }
          nuovo.add(giorno);
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
    if (_activeDates.isNotEmpty) {
      return _activeDates.map((date) {
        final iso = _isoDate(date);
        final orari = orariPerData[iso] ?? {};
        final giorno = <String, dynamic>{
          'data': iso,
          'km': '',
          'spese': '',
          'oraDa': (orari['oraDa'] ?? '').toString(),
          'oraA': (orari['oraA'] ?? '').toString(),
          'pausa': (orari['pausa'] ?? 'false').toString(),
          'pausaOre': (orari['pausaOre'] ?? '').toString(),
          'pausaMinuti': (orari['pausaMinuti'] ?? '').toString(),
        };
        giorno['ore'] = _calcolaOre(orari) ?? '';
        return giorno;
      }).toList();
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
                  'nome': formatPersonName(nome),
                  'giorni': _giorniPerRange(),
                  'segreteria': null,
                  'note': '',
                })
            .toList();
      }
    });
    _notifyDataChanged();
  }

  void setCronometristiPerDate(Map<String, List<DateTime>> datesByName) {
    Map<String, dynamic> dayData(DateTime date) {
      final iso = _isoDate(date);
      final orari = orariPerData[iso] ?? const {};
      final giorno = <String, dynamic>{
        'data': iso,
        'km': '',
        'spese': '',
        'oraDa': (orari['oraDa'] ?? '').toString(),
        'oraA': (orari['oraA'] ?? '').toString(),
        'pausa': (orari['pausa'] ?? 'false').toString(),
        'pausaOre': (orari['pausaOre'] ?? '').toString(),
        'pausaMinuti': (orari['pausaMinuti'] ?? '').toString(),
      };
      giorno['ore'] = _calcolaOre(orari) ?? '';
      return giorno;
    }

    setState(() {
      if (datesByName.isEmpty) {
        righe = [
          {
            'nome': null,
            'giorni': _giorniPerRange(),
            'segreteria': null,
            'note': '',
          }
        ];
      } else {
        final normalizedDatesByName = <String, List<DateTime>>{};
        for (final entry in datesByName.entries) {
          final name = formatPersonName(entry.key);
          normalizedDatesByName.putIfAbsent(name, () => []).addAll(entry.value);
        }
        final names = normalizedDatesByName.keys.toList()
          ..sort((first, second) =>
              first.toLowerCase().compareTo(second.toLowerCase()));
        righe = names.map((name) {
          final dates = normalizedDatesByName[name]!
              .map((date) => DateTime(date.year, date.month, date.day))
              .toSet()
              .toList()
            ..sort();
          return {
            'nome': name,
            'giorni': dates.map(dayData).toList(),
            'segreteria': null,
            'note': '',
          };
        }).toList();
      }
      _revision++;
    });
    _notifyDataChanged();
  }

  void setOrari(Map<String, Map<String, String>> orari) {
    final normalizzati = orari.map(
      (data, value) => MapEntry(data, {
        'oraDa': (value['oraDa'] ?? '').toString(),
        'oraA': (value['oraA'] ?? '').toString(),
        'pausa': (value['pausa'] ?? 'false').toString(),
        'pausaOre': (value['pausaOre'] ?? '').toString(),
        'pausaMinuti': (value['pausaMinuti'] ?? '').toString(),
      }),
    );
    final dateCambiate = <String>{
      ...orariPerData.keys,
      ...normalizzati.keys,
    }
        .where(
          (data) => !_stessoOrario(orariPerData[data], normalizzati[data]),
        )
        .toSet();

    setState(() {
      orariPerData = normalizzati;
      for (final riga in righe) {
        final giorni = (riga['giorni'] as List?) ?? [];
        for (final g in giorni) {
          final data = (g['data'] ?? '').toString();
          if (!dateCambiate.contains(data)) continue;
          final orariData = orariPerData[data] ?? {};
          g['oraDa'] = (orariData['oraDa'] ?? '').toString();
          g['oraA'] = (orariData['oraA'] ?? '').toString();
          g['pausa'] = (orariData['pausa'] ?? 'false').toString();
          g['pausaOre'] = (orariData['pausaOre'] ?? '').toString();
          g['pausaMinuti'] = (orariData['pausaMinuti'] ?? '').toString();
          final oreCalcolate = _calcolaOre(orariData);
          if (oreCalcolate != null) g['ore'] = oreCalcolate;
        }
      }
      _revision++;
    });
    _notifyDataChanged();
  }

  bool _stessoOrario(
    Map<String, String>? primo,
    Map<String, String>? secondo,
  ) {
    if (primo == null || secondo == null) return primo == secondo;
    const campi = ['oraDa', 'oraA', 'pausa', 'pausaOre', 'pausaMinuti'];
    return campi.every((campo) => primo[campo] == secondo[campo]);
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
          'pausa': 'false',
          'pausaOre': '',
          'pausaMinuti': '',
        };
      }
      return {
        'data': (raw['data'] ?? '').toString(),
        'ore': (raw['ore'] ?? '').toString(),
        'km': (raw['km'] ?? '').toString(),
        'spese': (raw['spese'] ?? '').toString(),
        'oraDa': (raw['oraDa'] ?? '').toString(),
        'oraA': (raw['oraA'] ?? '').toString(),
        'pausa': (raw['pausa'] ?? 'false').toString(),
        'pausaOre': (raw['pausaOre'] ?? '').toString(),
        'pausaMinuti': (raw['pausaMinuti'] ?? '').toString(),
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
        'nome': raw['nome'] == null ? null : formatPersonName(raw['nome']),
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
    final fill = colorScheme.surface.withOpacity(0.9);
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

  int? _minutiDaOrario(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})(?::?(\d{2}))?$').firstMatch(value);
    if (match == null) return null;
    final ore = int.tryParse(match.group(1)!);
    final minuti = int.tryParse(match.group(2) ?? '0');
    if (ore == null || minuti == null || ore > 23 || minuti > 59) return null;
    return ore * 60 + minuti;
  }

  String? _calcolaOre(Map<String, String> orari) {
    final inizio = _minutiDaOrario(orari['oraDa'] ?? '');
    final fine = _minutiDaOrario(orari['oraA'] ?? '');
    if (inizio == null || fine == null) return null;

    var minutiLavorati = fine - inizio;
    if (minutiLavorati < 0) minutiLavorati += 24 * 60;
    if ((orari['pausa'] ?? 'false') == 'true') {
      final oreInserite = int.tryParse(orari['pausaOre'] ?? '') ?? 0;
      final minutiInseriti = int.tryParse(orari['pausaMinuti'] ?? '') ?? 0;
      final orePausa = oreInserite < 0 ? 0 : oreInserite;
      final minutiPausa = minutiInseriti < 0 ? 0 : minutiInseriti;
      minutiLavorati -= orePausa * 60 + minutiPausa;
    }
    if (minutiLavorati < 0) minutiLavorati = 0;

    final value = (minutiLavorati / 60).toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatDateLabel(dynamic value, {int? index}) {
    final d = value?.toString() ?? '';
    if (d.isEmpty) return index != null ? "Giorno ${index + 1}: " : '';
    return formatItalianIsoDateOrValue(d, emptyValue: '');
  }

  String _isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Elaborazione Dati',
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
