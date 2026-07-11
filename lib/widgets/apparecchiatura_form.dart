import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ApparecchiaturaForm extends StatefulWidget {
  const ApparecchiaturaForm({super.key});

  @override
  ApparecchiaturaFormState createState() => ApparecchiaturaFormState();
}

class ApparecchiaturaFormState extends State<ApparecchiaturaForm> {
  static const Set<String> _legacyTabelloniDevices = {
    'alge',
    'microtab',
    'micrograph',
    'semaforo',
    'hiclock',
    'startclock',
  };

  int _revision = 0;
  bool tabellone = false;
  String tabelloneNumero = '';
  bool segreteria = false;
  String segreteriaGiorni = '';
  bool intermedi = false;
  String intermediNumero = '';
  bool trasmissioneDati = false;
  String trasmissioneDatiNumero = '';
  bool IDcam = false;
  String IDcamNumero = '';
  String altreApparecchiature = '';

  List<Map<String, dynamic>> getData() {
    return [
      {
        'guidedMode': true,
        'tabellone': tabellone ? 'SI' : 'NO',
        'tabelloneNumero': tabellone ? tabelloneNumero.trim() : '',
        'segreteria': segreteria ? 'SI' : 'NO',
        'segreteriaGiorni': segreteria ? segreteriaGiorni.trim() : '',
        'intermedi': intermedi ? 'SI' : 'NO',
        'intermediNumero': intermedi ? intermediNumero.trim() : '',
        'trasmissioneDati': trasmissioneDati ? 'SI' : 'NO',
        'trasmissioneDatiNumero':
            trasmissioneDati ? trasmissioneDatiNumero.trim() : '',
        'IDcam': IDcam ? 'SI' : 'NO',
        'IDcamNumero': IDcam ? IDcamNumero.trim() : '',
        'altreApparecchiature': altreApparecchiature.trim(),
      }
    ];
  }

  void applySavedData(List<dynamic> savedRows) {
    setState(() {
      _resetState();
      if (savedRows.isEmpty) {
        _revision++;
        return;
      }

      final first = savedRows.first;
      if (first is Map) {
        if (first['guidedMode'] == true) {
          _applyGuidedData(first);
        } else {
          _applyLegacyData(savedRows);
        }
      }
      _revision++;
    });
  }

  void _applyGuidedData(Map data) {
    tabellone = _readSiNo(data, ['tabellone']);
    tabelloneNumero = _readValue(data, ['tabelloneNumero']);
    segreteria = _readSiNo(data, ['segreteria']);
    segreteriaGiorni =
        _readValue(data, ['segreteriaGiorni', 'giornateSegreteria']);
    intermedi = _readSiNo(data, ['intermedi']);
    intermediNumero = _readValue(data, ['intermediNumero']);
    trasmissioneDati = _readSiNo(data, ['trasmissioneDati']);
    trasmissioneDatiNumero = _readValue(data, ['trasmissioneDatiNumero']);
    IDcam = _readSiNo(data, ['IDcam']);
    IDcamNumero = _readValue(data, ['IDcamNumero']);
    altreApparecchiature = _readValue(data, ['altreApparecchiature']);
  }

  void _applyLegacyData(List<dynamic> savedRows) {
    final otherEntries = <String>[];

    for (final row in savedRows.whereType<Map>()) {
      final fisMode = row['fisMode'] == true;
      if (fisMode) {
        tabellone = _readValue(row, ['quantita']).toUpperCase() == 'SI';
        segreteriaGiorni = _readValue(row, [
          'giornateSegreteria',
          'gionrateSegreteria',
          'numeroGiornateSegreteria',
          'numeroGionrateSegreteria',
          'NUMERO GIORNATE SEGRETERIA',
          'NUMERO GIONRATE SEGRETERIA',
          'NUMERO GIORNATE DI SEGRETERIA',
          'NUMERO GIONRATE DI SEGRETERIA',
        ]);
        segreteria = segreteriaGiorni.isNotEmpty;
        continue;
      }

      final dispositivo = _readValue(row, ['dispositivo']);
      if (dispositivo.isEmpty) continue;
      final quantita = _readValue(row, ['quantita']);
      final lower = dispositivo.toLowerCase();

      if (_legacyTabelloniDevices.contains(lower)) {
        tabellone = true;
        if (tabelloneNumero.isEmpty) {
          tabelloneNumero = quantita;
        }
      } else {
        otherEntries.add(
          quantita.isEmpty ? dispositivo : '$dispositivo ($quantita)',
        );
      }
    }

    altreApparecchiature = otherEntries.join(', ');
  }

  bool _readSiNo(Map data, List<String> keys) {
    final value = _readValue(data, keys).toUpperCase();
    return value == 'SI';
  }

  String _readValue(Map data, List<String> keys) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  void _resetState() {
    tabellone = false;
    tabelloneNumero = '';
    segreteria = false;
    segreteriaGiorni = '';
    intermedi = false;
    intermediNumero = '';
    trasmissioneDati = false;
    trasmissioneDatiNumero = '';
    IDcam = false;
    IDcamNumero = '';
    altreApparecchiature = '';
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

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String fieldLabel,
    required String fieldValue,
    required ValueChanged<String> onFieldChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value ? 'SÌ' : 'NO',
                    style: TextStyle(
                      color: value
                          ? const Color(0xFF007AFF)
                          : colorScheme.onSurface.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoSwitch(
                    value: value,
                    activeTrackColor: const Color(0xFF007AFF),
                    onChanged: (next) {
                      onChanged(next);
                      if (!next) {
                        onFieldChanged('');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              child: TextFormField(
                key: ValueKey('$title-$_revision'),
                initialValue: fieldValue,
                keyboardType: TextInputType.number,
                onChanged: onFieldChanged,
                decoration: InputDecoration(
                  labelText: fieldLabel,
                  hintText: 'Es. 1',
                  filled: true,
                  fillColor: colorScheme.surface.withOpacity(0.95),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Apparecchiatura',
          subtitle: 'Compila solo le voci effettivamente utilizzate.',
          icon: Icons.precision_manufacturing_rounded,
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          title: 'Tabellone',
          subtitle: 'Indica se e quanti tabelloni sono stati utilizzati.',
          value: tabellone,
          onChanged: (val) => setState(() => tabellone = val),
          fieldLabel: 'Numero tabelloni',
          fieldValue: tabelloneNumero,
          onFieldChanged: (val) => tabelloneNumero = val,
        ),
        _buildToggleRow(
          title: 'Segreteria',
          subtitle: 'Indica se il servizio di segreteria era previsto.',
          value: segreteria,
          onChanged: (val) => setState(() => segreteria = val),
          fieldLabel: 'Numero giorni',
          fieldValue: segreteriaGiorni,
          onFieldChanged: (val) => segreteriaGiorni = val,
        ),
        _buildToggleRow(
          title: 'Intermedi',
          subtitle: 'Indica se erano presenti punti intermedi.',
          value: intermedi,
          onChanged: (val) => setState(() => intermedi = val),
          fieldLabel: 'Numero intermedi',
          fieldValue: intermediNumero,
          onFieldChanged: (val) => intermediNumero = val,
        ),
        _buildToggleRow(
          title: 'Trasmissione dati',
          subtitle: 'Indica se sono stati usati sistemi di trasmissione dati.',
          value: trasmissioneDati,
          onChanged: (val) => setState(() => trasmissioneDati = val),
          fieldLabel: 'Numero apparati',
          fieldValue: trasmissioneDatiNumero,
          onFieldChanged: (val) => trasmissioneDatiNumero = val,
        ),
        _buildToggleRow(
          title: 'IDcam',
          subtitle: 'Indica se sono state utilizzate IDcam.',
          value: IDcam,
          onChanged: (val) => setState(() => IDcam = val),
          fieldLabel: 'Numero IDcam',
          fieldValue: IDcamNumero,
          onFieldChanged: (val) => IDcamNumero = val,
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
          ),
          child: TextFormField(
            key: ValueKey('altre-apparecchiature-$_revision'),
            initialValue: altreApparecchiature,
            maxLines: 3,
            onChanged: (val) => altreApparecchiature = val,
            decoration: InputDecoration(
              labelText: 'Altre apparecchiature',
              hintText: 'Indica eventuali altre apparecchiature utilizzate',
              filled: true,
              fillColor: colorScheme.surface.withOpacity(0.95),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
