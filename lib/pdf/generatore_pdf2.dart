import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

const Set<String> _tabelloniDevices = {
  'alge',
  'microtab',
  'micrograph',
  'semaforo',
  'hiclock',
  'startclock',
};

const PdfColor _tableBorderColor = PdfColors.grey600;
const PdfColor _tableHeaderColor = PdfColors.grey200;
const PdfColor _tableHeaderTextColor = PdfColors.black;
const PdfColor _tableAltRowColor = PdfColors.white;

String _sanitizeText(String value) {
  const replacements = {
    '\u2019': "'",
    '\u2018': "'",
    '\u2032': "'",
    '\u02BC': "'",
    '\u02BB': "'",
    '\u0060': "'",
    '\u00B4': "'",
    '\u201C': '"',
    '\u201D': '"',
    '\u2033': '"',
  };
  var result = value;
  replacements.forEach((from, to) {
    result = result.replaceAll(from, to);
  });
  return result;
}

String _txt(Object? value) => _sanitizeText((value ?? '').toString());

String _safeFileName(String raw) {
  // Remove path separators and other invalid filename characters, and trim spaces.
  final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final noSpaces = cleaned.replaceAll(RegExp(r'\\s+'), '');
  final noTrailingDots = noSpaces.replaceAll(RegExp(r'[.]+$'), '');
  return noTrailingDots.isEmpty ? 'Rapporto' : noTrailingDots;
}

Future<File> generaPdfConDati(
  Map<String, dynamic> dati, {
  bool salvaLocalmente = false,
}) async {
  final pdf = await _buildPdfDocument(dati);

  final dir = await getApplicationDocumentsDirectory();
  final String nomeGara =
      _safeFileName(_txt(((dati['gara'] ?? {})['nome'] ?? 'Rapporto')));
  final String dataFile = ((dati['gara'] ?? {})['dataDa'] ?? '00000000')
      .toString()
      .replaceAll('-', '');

  final String nomeFile = '${dataFile}_$nomeGara.pdf';
  final file = File('${dir.path}/$nomeFile');
  await file.writeAsBytes(await pdf.save());
  return file;
}

Future<Uint8List> generaPdfBytesConDati(Map<String, dynamic> dati) async {
  final pdf = await _buildPdfDocument(dati);
  return pdf.save();
}

Future<pw.Document> _buildPdfDocument(Map<String, dynamic> dati) async {
  final pdf = pw.Document();

  final base = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final gara = (dati['gara'] ?? {}) as Map<String, dynamic>;
  final pacchettoRaw = dati['pacchetto'];
  final pacchetto = pacchettoRaw is Map
      ? Map<String, dynamic>.from(pacchettoRaw)
      : <String, dynamic>{};

  // Load logo from assets if available
  final Uint8List? logoBytes = await _loadAssetSafe('assets/logo.png');
  final pw.ImageProvider? logoImage =
      logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  final cronos = (dati['cronometristi'] ?? []) as List;
  final apparecchiature = (dati['apparecchiature'] ?? []) as List;
  final danni = _txt(dati['danni']);
  final allegati = (dati['allegati'] ?? []) as List;
  final allegatiBytes = await _loadAllegatiBytes(allegati);
  final direttore = _txt(gara['dsc']).trim();
  final orariGiornata = normalizzaOrariGiornataPdf(dati['orariGiornata']);
  final mostraRiepilogo = pacchetto['attivo'] == true || _isMultiDay(gara);
  final contenuto = <pw.Widget>[
    _sezioneGara(gara, pacchetto, base, bold),
    pw.SizedBox(height: 12),
    _sezioneCronometristi(
      cronos,
      base,
      bold,
      mostraRiepilogo: mostraRiepilogo,
      orariGiornata: orariGiornata,
    ),
    pw.SizedBox(height: 12),
    _sezioneApparecchiatura(apparecchiature, base, bold),
    pw.SizedBox(height: 12),
    _sezioneDanni(danni, base, bold),
  ];

  if (allegatiBytes.isNotEmpty) {
    contenuto
        .addAll([pw.SizedBox(height: 12), _sezioneAllegati(allegatiBytes)]);
  }

  if (direttore.isNotEmpty) {
    contenuto.addAll([
      pw.SizedBox(height: 12),
      _sezioneDirettore(direttore, base, bold),
    ]);
  }

  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        margin: pw.EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      ),
      header: (context) => _header(bold, logo: logoImage),
      footer: (context) =>
          _footer(base, context.pageNumber, context.pagesCount),
      build: (context) => contenuto,
    ),
  );

  return pdf;
}

// ===== Sezioni =====
pw.Widget _sezioneGara(
  Map<String, dynamic> gara,
  Map<String, dynamic> pacchetto,
  pw.Font base,
  pw.Font bold,
) {
  String fmt(String? iso) {
    iso = _txt(iso);
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return _txt(iso);
    }
  }

  final nome = _txt(gara['nome']);
  final organizzatore = _txt(gara['organizzatore']);
  final sport = _txt(gara['sport']);
  final luogo = _txt(gara['luogo']);
  final dataDa = fmt(gara['dataDa']?.toString());
  final dataA = fmt(gara['dataA']?.toString());
  final dsc = _txt(gara['dsc']);
  final packageDays = (pacchetto['giornate'] as List? ?? const [])
      .map((value) => fmt(value?.toString()))
      .where((value) => value.isNotEmpty)
      .join(', ');
  final isPackage = pacchetto['attivo'] == true;

  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(font: bold, fontSize: 12),
              ),
              pw.TextSpan(
                text: value.isEmpty ? '-' : _txt(value),
                style: pw.TextStyle(font: base, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  pw.Widget infoColumn(List<MapEntry<String, String>> entries) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children:
            entries.map((entry) => infoRow(entry.key, entry.value)).toList(),
      );

  final entries = <MapEntry<String, String>>[
    MapEntry('Gara', nome),
    MapEntry('Organizzatore', organizzatore),
    MapEntry('Sport', sport),
    MapEntry('Luogo', luogo),
    if (isPackage) MapEntry('Giornate incluse', packageDays),
    if (!isPackage) MapEntry('Data da', dataDa),
    if (!isPackage) MapEntry('Data a', dataA),
    if (dsc.isNotEmpty) MapEntry('DSC', dsc),
  ];

  final splitIndex = (entries.length / 2).ceil();
  final left = entries.sublist(0, splitIndex);
  final right = entries.sublist(splitIndex);

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _tableBorderColor),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: infoColumn(left)),
        if (right.isNotEmpty) ...[
          pw.SizedBox(width: 24),
          pw.Expanded(child: infoColumn(right)),
        ],
      ],
    ),
  );
}

bool _isMultiDay(Map<String, dynamic> gara) {
  DateTime? parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  final da = parse(gara['dataDa']?.toString());
  final a = parse(gara['dataA']?.toString());
  if (da == null || a == null) return false;
  return a.difference(da).inDays > 0;
}

pw.Widget _sezioneCronometristi(
  List elenco,
  pw.Font base,
  pw.Font bold, {
  bool mostraRiepilogo = true,
  Map<String, dynamic> orariGiornata = const {},
}) {
  double sum(List giorni, String campo) {
    return giorni.fold<double>(0, (t, g) {
      final v = g[campo];
      if (v == null) return t;
      if (v is num) return t + v.toDouble();
      if (v is String) return t + (double.tryParse(v) ?? 0);
      return t;
    });
  }

  final rows = <List<String>>[];
  final noteRows = <List<String>>[];
  double totOre = 0, totKm = 0, totSpese = 0;
  for (final c in elenco) {
    final giorni = (c['giorni'] as List?) ?? [];
    final ore = sum(giorni, 'ore');
    final km = sum(giorni, 'km');
    final spese = sum(giorni, 'spese');
    final segreteria = _txt(c['segreteria']).toUpperCase();
    final note = _txt(c['note']);
    totOre += ore;
    totKm += km;
    totSpese += spese;
    rows.add([
      _txt(c['nome']),
      ore.toStringAsFixed(1),
      km.toStringAsFixed(1),
      spese.toStringAsFixed(2),
      segreteria,
      note,
    ]);
    if (note.trim().isNotEmpty) {
      noteRows.add([_txt(c['nome']), note]);
    }
  }

  final children = <pw.Widget>[
    pw.Text('Cronometristi', style: pw.TextStyle(font: bold, fontSize: 13)),
    pw.SizedBox(height: 6),
    _sezioneGiornate(
      elenco,
      base,
      bold,
      orariGiornata: orariGiornata,
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      '',
      style: pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700),
    ),
  ];

  if (mostraRiepilogo && rows.isNotEmpty) {
    children.addAll([
      pw.SizedBox(height: 10),
      pw.Text(
        'Riepilogo cronometristi',
        style: pw.TextStyle(font: bold, fontSize: 13),
      ),
      pw.SizedBox(height: 5),
      _tabellaRiepilogo(rows, totOre, totKm, totSpese, base, bold),
      pw.SizedBox(height: 3),
      //pw.Text('* Specificare SI/NO',
      //    style:
      //        pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700)),
    ]);
  }
  if (!mostraRiepilogo && noteRows.isNotEmpty) {
    children.addAll([
      pw.SizedBox(height: 10),
      pw.Text(
        'Note cronometristi',
        style: pw.TextStyle(font: bold, fontSize: 13),
      ),
      pw.SizedBox(height: 5),
      _tabellaNoteCronometristi(noteRows, base, bold),
    ]);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: children,
  );
}

pw.Widget _tabellaNoteCronometristi(
  List<List<String>> rows,
  pw.Font base,
  pw.Font bold,
) {
  pw.Widget cell(
    String text, {
    bool header = false,
    PdfColor? background,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: header ? _tableHeaderColor : background,
        child: pw.Text(
          _txt(text),
          style: pw.TextStyle(
            font: header ? bold : base,
            color: header ? _tableHeaderTextColor : PdfColors.black,
            fontSize: 10,
          ),
        ),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _tableBorderColor),
    columnWidths: const {
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(5),
    },
    children: [
      pw.TableRow(
        children: [
          cell('Cronometrista', header: true),
          cell('Note', header: true),
        ],
      ),
      ...rows.asMap().entries.map((entry) {
        final idx = entry.key;
        final row = entry.value;
        final rowBg = idx.isOdd ? _tableAltRowColor : null;
        return pw.TableRow(
          children: [
            cell(row[0], background: rowBg),
            cell(row[1], background: rowBg),
          ],
        );
      }),
    ],
  );
}

// Raggruppa per data (yyyy-MM-dd) e stampa una tabella per giornata
pw.Widget _sezioneGiornate(
  List elenco,
  pw.Font base,
  pw.Font bold, {
  Map<String, dynamic> orariGiornata = const {},
}) {
  final Map<String, Map<String, String>> orariPerData = {};
  orariGiornata.forEach((key, value) {
    if (value is Map) {
      orariPerData[key.toString()] = {
        'oraDa': (value['oraDa'] ?? '').toString(),
        'oraA': (value['oraA'] ?? '').toString(),
        'pausa': (value['pausa'] ?? 'false').toString(),
        'pausaOre': (value['pausaOre'] ?? '').toString(),
        'pausaMinuti': (value['pausaMinuti'] ?? '').toString(),
      };
    }
  });

  final Map<String, List<Map<String, String>>> perData = {};
  for (final c in elenco) {
    final nome = _txt(c['nome']);
    final segreteria = _txt(c['segreteria']).toUpperCase();
    final giorni = (c['giorni'] as List?) ?? [];
    for (final g in giorni) {
      final dIso = _txt(g['data']);
      if (dIso.isEmpty) continue;
      final ore = _txt(g['ore']);
      final km = _txt(g['km']);
      final spese = _txt(g['spese']);
      final oraDa = _txt(g['oraDa']);
      final oraA = _txt(g['oraA']);
      final pausa = _txt(g['pausa']);
      final pausaOre = _txt(g['pausaOre']);
      final pausaMinuti = _txt(g['pausaMinuti']);
      if (!orariPerData.containsKey(dIso) &&
          (oraDa.isNotEmpty || oraA.isNotEmpty)) {
        orariPerData[dIso] = {
          'oraDa': oraDa,
          'oraA': oraA,
          'pausa': pausa,
          'pausaOre': pausaOre,
          'pausaMinuti': pausaMinuti,
        };
      }
      perData.putIfAbsent(dIso, () => []);
      perData[dIso]!.add({
        'nome': nome,
        'ore': ore,
        'km': km,
        'spese': spese,
        'segreteria': segreteria,
      });
    }
  }

  final dates = perData.keys.toList()..sort();
  if (dates.isEmpty) {
    return pw.Text(
      'Nessun cronometrista registrato',
      style: pw.TextStyle(font: base),
    );
  }

  final widgets = <pw.Widget>[];
  for (int i = 0; i < dates.length; i++) {
    final d = dates[i];
    final rows = perData[d]!..sort((a, b) => a['nome']!.compareTo(b['nome']!));
    final orari = _orariForDate(orariPerData, d);
    final orarioLabel = _formatOrarioRange(orari['oraDa'], orari['oraA']);
    final pausaLabel = _formatPausa(orari);
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _tableBorderColor),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: const pw.BoxDecoration(color: _tableHeaderColor),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'GIORNO ${i + 1}',
                        style: pw.TextStyle(font: bold, fontSize: 12),
                      ),
                      pw.Text(
                        _formatDateHuman(d),
                        style: pw.TextStyle(font: base, fontSize: 11),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Orario: $orarioLabel',
                    style: pw.TextStyle(font: base, fontSize: 9),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'Pausa: $pausaLabel',
                    style: pw.TextStyle(font: base, fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: _tableBorderColor),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1.3),
              },
              children: [
                _giornoHeaderRow(bold),
                ...rows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final rowBg = idx.isOdd ? _tableAltRowColor : null;
                  final segreteria = _fmtValue(r['segreteria']).toUpperCase();
                  return pw.TableRow(
                    children: [
                      _giornoCell(r['nome'] ?? '', base, background: rowBg),
                      _giornoCell(
                        _fmtValue(r['ore']),
                        base,
                        center: true,
                        background: rowBg,
                      ),
                      _giornoCell(
                        _fmtValue(r['km']),
                        base,
                        center: true,
                        background: rowBg,
                      ),
                      _giornoCell(
                        _fmtValue(r['spese']),
                        base,
                        center: true,
                        background: rowBg,
                      ),
                      _giornoCell(
                        segreteria,
                        base,
                        center: true,
                        background: rowBg,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  return pw.Column(children: widgets);
}

pw.Widget _sezioneApparecchiatura(List elenco, pw.Font base, pw.Font bold) {
  final summary = _parseApparecchiaturaSummary(elenco);
  final rows = [
    _equipmentRow(
      'Tabellone',
      summary['tabelloneSi'],
      summary['tabelloneNumero'],
      valueSuffix: 'unita',
    ),
    _equipmentRow(
      'Elaborazione Dati',
      summary['segreteriaSi'],
      summary['segreteriaGiorni'],
      valueSuffix: 'giorni',
    ),
    _equipmentRow(
      'Intermedi',
      summary['intermediSi'],
      summary['intermediNumero'],
      valueSuffix: 'unita',
    ),
    _equipmentRow(
      'Trasmissione dati',
      summary['trasmissioneDatiSi'],
      summary['trasmissioneDatiNumero'],
      valueSuffix: 'unita',
    ),
    _equipmentRow(
      'IDcam',
      summary['IDcamSi'],
      summary['IDcamNumero'],
      valueSuffix: 'unita',
    ),
  ];
  final altreApparecchiature = _txt(summary['altreApparecchiature']).trim();

  pw.Widget cell(
    String text, {
    bool header = false,
    bool center = false,
    PdfColor? background,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        color: header ? _tableHeaderColor : background,
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(
          _txt(text),
          style: pw.TextStyle(
            font: header ? bold : base,
            color: header ? _tableHeaderTextColor : PdfColors.black,
            fontSize: 10,
          ),
        ),
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Apparecchiature impiegate',
        style: pw.TextStyle(font: bold, fontSize: 13),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: _tableBorderColor),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.4),
          1: pw.FlexColumnWidth(4.6)
        },
        children: [
          pw.TableRow(
            children: [
              cell('Voce', header: true, center: true),
              cell('Dettaglio', header: true, center: true),
            ],
          ),
          for (int i = 0; i < rows.length; i++)
            pw.TableRow(
              children: [
                cell(rows[i][0],
                    background: i.isOdd ? _tableAltRowColor : null),
                cell(rows[i][1],
                    background: i.isOdd ? _tableAltRowColor : null),
              ],
            ),
        ],
      ),
      if (altreApparecchiature.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: 'Altro: ',
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
              pw.TextSpan(
                text: altreApparecchiature,
                style: pw.TextStyle(font: base, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

List<String> _equipmentRow(
  String label,
  Object? enabledRaw,
  Object? detailRaw, {
  String valueSuffix = '',
}) {
  final enabled = enabledRaw == true;
  final detail = _txt(detailRaw).trim();
  if (!enabled) return [label, 'NO'];
  if (detail.isEmpty) return [label, 'SI'];
  return [
    label,
    valueSuffix.isEmpty ? 'SI ($detail)' : 'SI ($detail $valueSuffix)',
  ];
}

pw.Widget _sezioneDanni(String testo, pw.Font base, pw.Font bold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Note / Malfunzionamenti',
        style: pw.TextStyle(font: bold, fontSize: 13),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          testo.isEmpty ? '-' : _txt(testo),
          style: pw.TextStyle(font: base),
        ),
      ),
    ],
  );
}

pw.Widget _sezioneDirettore(String direttore, pw.Font base, pw.Font bold) {
  final text = direttore.trim();
  if (text.isEmpty) return pw.SizedBox.shrink();
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'Direttore Servizio di Cronometraggio',
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
        pw.SizedBox(height: 3),
        pw.Text(_txt(text), style: pw.TextStyle(font: base, fontSize: 11)),
      ],
    ),
  );
}

pw.Widget _sezioneAllegati(List<Uint8List> allegati) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Allegati fotografici',
        style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 12),
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: allegati.map<pw.Widget>((bytes) {
          final image = pw.MemoryImage(bytes);
          return pw.Container(
            width: 240,
            height: 160,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Image(image, fit: pw.BoxFit.cover),
          );
        }).toList(),
      ),
    ],
  );
}

Future<List<Uint8List>> _loadAllegatiBytes(List allegati) async {
  final out = <Uint8List>[];
  for (final item in allegati) {
    if (item is XFile) {
      try {
        final bytes = await item.readAsBytes();
        if (bytes.isNotEmpty) out.add(ottimizzaAllegatoPdf(bytes));
      } catch (_) {}
      continue;
    }

    if (!kIsWeb && item is File) {
      try {
        final bytes = item.readAsBytesSync();
        if (bytes.isNotEmpty) out.add(ottimizzaAllegatoPdf(bytes));
      } catch (_) {}
      continue;
    }

    if (!kIsWeb) {
      final dynamic dynamicItem = item;
      try {
        final path = dynamicItem.path;
        if (path is String && path.isNotEmpty) {
          final file = File(path);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.isNotEmpty) out.add(ottimizzaAllegatoPdf(bytes));
          }
        }
      } catch (_) {}
    }
  }
  return out;
}

Uint8List ottimizzaAllegatoPdf(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final oriented = img.bakeOrientation(decoded);
  const maxSide = 1280;
  final resized = oriented.width <= maxSide && oriented.height <= maxSide
      ? oriented
      : oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxSide)
          : img.copyResize(oriented, height: maxSide);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
}

pw.Widget _tabellaRiepilogo(
  List<List<String>> rows,
  double totOre,
  double totKm,
  double totSpese,
  pw.Font base,
  pw.Font bold,
) {
  pw.Widget cell(
    String text, {
    bool header = false,
    bool boldText = false,
    bool center = false,
    PdfColor? background,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        color: header ? _tableHeaderColor : background,
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(
          _txt(text),
          style: pw.TextStyle(
            font: boldText ? bold : base,
            color: header ? _tableHeaderTextColor : PdfColors.black,
            fontSize: 10,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
          maxLines: 2,
          softWrap: true,
        ),
      );

  return pw.Table(
    border: pw.TableBorder.all(color: _tableBorderColor),
    columnWidths: const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
      3: pw.FlexColumnWidth(1.4),
      4: pw.FlexColumnWidth(1.2),
      5: pw.FlexColumnWidth(3),
    },
    children: [
      pw.TableRow(
        children: [
          cell('Nome', header: true, center: true),
          cell('Ore', header: true, center: true),
          cell('Km', header: true, center: true),
          cell('Spese', header: true, center: true),
          cell('Elaborazione\nDati', header: true, center: true),
          cell('Note', header: true, center: true),
        ],
      ),
      ...rows.asMap().entries.map((entry) {
        final index = entry.key;
        final r = entry.value;
        final rowBg = index.isOdd ? _tableAltRowColor : null;
        return pw.TableRow(
          children: [
            cell(r[0], background: rowBg),
            cell(r[1], center: true, background: rowBg),
            cell(r[2], center: true, background: rowBg),
            cell(r[3], center: true, background: rowBg),
            cell(r[4], center: true, background: rowBg),
            cell(r[5], background: rowBg),
          ],
        );
      }),
      pw.TableRow(
        children: [
          cell('Totali', boldText: true, background: _tableAltRowColor),
          cell(
            totOre.toStringAsFixed(1),
            boldText: true,
            center: true,
            background: _tableAltRowColor,
          ),
          cell(
            totKm.toStringAsFixed(1),
            boldText: true,
            center: true,
            background: _tableAltRowColor,
          ),
          cell(
            totSpese.toStringAsFixed(2),
            boldText: true,
            center: true,
            background: _tableAltRowColor,
          ),
          cell('', boldText: true, background: _tableAltRowColor),
          cell('', boldText: true, background: _tableAltRowColor),
        ],
      ),
    ],
  );
}

Map<String, dynamic> _parseApparecchiaturaSummary(List elenco) {
  final out = <String, dynamic>{
    'tabelloneSi': false,
    'tabelloneNumero': '',
    'segreteriaSi': false,
    'segreteriaGiorni': '',
    'intermediSi': false,
    'intermediNumero': '',
    'trasmissioneDatiSi': false,
    'trasmissioneDatiNumero': '',
    'IDcamSi': false,
    'IDcamNumero': '',
    'altreApparecchiature': '',
  };

  if (elenco.isEmpty) return out;
  final first = elenco.first;
  if (first is Map && first['guidedMode'] == true) {
    out['tabelloneSi'] = _isSi(first['tabellone']);
    out['tabelloneNumero'] = _txt(first['tabelloneNumero']).trim();
    out['segreteriaSi'] = _isSi(first['segreteria']);
    out['segreteriaGiorni'] = _txt(first['segreteriaGiorni']).trim();
    out['intermediSi'] = _isSi(first['intermedi']);
    out['intermediNumero'] = _txt(first['intermediNumero']).trim();
    out['trasmissioneDatiSi'] = _isSi(first['trasmissioneDati']);
    out['trasmissioneDatiNumero'] =
        _txt(first['trasmissioneDatiNumero']).trim();
    out['IDcamSi'] = _isSi(first['IDcam']);
    out['IDcamNumero'] = _txt(first['IDcamNumero']).trim();
    out['altreApparecchiature'] = _txt(first['altreApparecchiature']).trim();
    return out;
  }

  final altre = <String>[];
  for (final voce in elenco) {
    if (voce is! Map) continue;
    if (voce['fisMode'] == true) {
      out['tabelloneSi'] = _isSi(voce['quantita']);
      final segreteriaGiorni = _legacySegreteriaGiorni(voce);
      out['segreteriaGiorni'] = segreteriaGiorni;
      out['segreteriaSi'] = segreteriaGiorni.isNotEmpty;
      continue;
    }

    final nome = _txt(voce['dispositivo']).trim();
    if (nome.isEmpty) continue;
    final qty = _txt(voce['quantita']).trim();
    final key = nome.toLowerCase();
    if (_tabelloniDevices.contains(key)) {
      out['tabelloneSi'] = true;
      if (_txt(out['tabelloneNumero']).trim().isEmpty) {
        out['tabelloneNumero'] = qty;
      }
      continue;
    }
    altre.add(qty.isEmpty ? nome : '$nome ($qty)');
  }

  out['altreApparecchiature'] = altre.join(', ');
  return out;
}

String _legacySegreteriaGiorni(Map voce) {
  const keys = [
    'giornateSegreteria',
    'gionrateSegreteria',
    'numeroGiornateSegreteria',
    'numeroGionrateSegreteria',
    'NUMERO GIORNATE SEGRETERIA',
    'NUMERO GIONRATE SEGRETERIA',
    'NUMERO GIORNATE DI SEGRETERIA',
    'NUMERO GIONRATE DI SEGRETERIA',
  ];
  for (final key in keys) {
    final value = _txt(voce[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool _isSi(Object? value) {
  final upper = _txt(value).trim().toUpperCase();
  return upper == 'SI';
}

pw.TableRow _giornoHeaderRow(pw.Font bold) => pw.TableRow(
      children: [
        _giornoCell('Cronometrista', bold, header: true),
        _giornoCell('Ore', bold, header: true, center: true),
        _giornoCell('Km', bold, header: true, center: true),
        _giornoCell('Spese', bold, header: true, center: true),
        _giornoCell('Elaborazione\nDati', bold, header: true, center: true),
      ],
    );

pw.Widget _giornoCell(
  String text,
  pw.Font font, {
  bool header = false,
  bool center = false,
  PdfColor? background,
}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      color: background ?? (header ? _tableHeaderColor : null),
      child: pw.Text(
        _txt(text),
        style: pw.TextStyle(
          font: font,
          color: header ? _tableHeaderTextColor : PdfColors.black,
          fontSize: 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: header ? 2 : null,
        softWrap: true,
      ),
    );

String _formatDateHuman(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return _txt(iso);
  }
}

String _fmtValue(String? value) {
  final sanitized = _txt(value);
  if (sanitized.isEmpty) return '-';
  return sanitized;
}

Map<String, String> _orariForDate(
  Map<String, Map<String, String>> orariPerData,
  String iso,
) {
  final raw = orariPerData[iso];
  if (raw == null) {
    return {
      'oraDa': '',
      'oraA': '',
      'pausa': 'false',
      'pausaOre': '',
      'pausaMinuti': '',
    };
  }
  return {
    'oraDa': _txt(raw['oraDa']),
    'oraA': _txt(raw['oraA']),
    'pausa': _txt(raw['pausa']),
    'pausaOre': _txt(raw['pausaOre']),
    'pausaMinuti': _txt(raw['pausaMinuti']),
  };
}

String _formatOrarioRange(String? da, String? a) {
  final start = _txt(da).trim();
  final end = _txt(a).trim();
  if (start.isEmpty && end.isEmpty) return '-';
  final startLabel = start.isEmpty ? '-' : start;
  final endLabel = end.isEmpty ? '-' : end;
  return '$startLabel - $endLabel';
}

String _formatPausa(Map<String, String> orari) {
  final ore = int.tryParse(orari['pausaOre'] ?? '') ?? 0;
  final minuti = int.tryParse(orari['pausaMinuti'] ?? '') ?? 0;
  final flag = (orari['pausa'] ?? '').trim().toLowerCase();
  final pausaDichiarata = const {'true', '1', 'si', 'sì', 'yes'}.contains(flag);
  final haDurata = ore > 0 || minuti > 0;
  if (!pausaDichiarata && !haDurata) return 'No';
  final parts = <String>[];
  if (ore > 0) parts.add('$ore h');
  if (minuti > 0) parts.add('$minuti min');
  return parts.isEmpty ? 'Sì' : 'Sì, ${parts.join(' ')}';
}

Map<String, dynamic> normalizzaOrariGiornataPdf(dynamic rawOrari) {
  final result = <String, dynamic>{};
  if (rawOrari is! Map) return result;
  rawOrari.forEach((key, value) {
    if (value is! Map) return;
    result[key.toString()] = {
      'oraDa': _txt(value['oraDa']),
      'oraA': _txt(value['oraA']),
      'pausa': _txt(value['pausa']),
      'pausaOre': _txt(value['pausaOre']),
      'pausaMinuti': _txt(value['pausaMinuti']),
    };
  });
  return result;
}

// ===== Header & Footer =====
pw.Widget _header(pw.Font bold, {pw.ImageProvider? logo}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ASD Cronometristi Valtellinesi',
                style: pw.TextStyle(font: bold, fontSize: 11),
              ),
              pw.Text(
                'Piazzale Valgoi, 5',
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9),
              ),
              pw.Text(
                '23100 - Sondrio',
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9),
              ),
            ],
          ),
          if (logo != null)
            pw.Container(
              width: 90,
              height: 90,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 48,
              height: 48,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
                borderRadius: pw.BorderRadius.circular(24),
              ),
              child: pw.Text(
                'LOGO',
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
            ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          'RAPPORTO DI SERVIZIO',
          style: pw.TextStyle(font: bold, fontSize: 16),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Divider(color: PdfColors.grey400),
    ],
  );
}

pw.Widget _footer(pw.Font base, int page, int pages) {
  final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'Generato: $now',
        style:
            pw.TextStyle(font: base, fontSize: 8.5, color: PdfColors.grey700),
      ),
      pw.Text(
        'Pagina $page di $pages',
        style:
            pw.TextStyle(font: base, fontSize: 8.5, color: PdfColors.grey700),
      ),
    ],
  );
}

Future<Uint8List?> _loadAssetSafe(String path) async {
  try {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
