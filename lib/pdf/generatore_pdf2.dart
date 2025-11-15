import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

const Set<String> _cronometriDevices = {
  'rei pro',
  'rei 2',
  'master 3',
  'master',
  'timy',
};

const Set<String> _tabelloniDevices = {
  'alge',
  'microtab',
  'micrograph',
  'semaforo',
  'hiclock',
  'startclock',
};

const Set<String> _varieDevices = {
  'cancelletto',
  'fotocellula',
  'startbeep',
  'cuffie',
  'chip machsa',
  'pressostato',
  'smartphone',
};

const PdfColor _tableBorderColor = PdfColor.fromInt(0xFF8BB8E8);
const PdfColor _tableHeaderColor = PdfColor.fromInt(0xFFD9EEFF);
const PdfColor _tableHeaderTextColor = PdfColors.blueGrey900;
const PdfColor _tableAltRowColor = PdfColor.fromInt(0xFFF2F8FF);

Future<File> generaPdfConDati(Map<String, dynamic> dati,
    {bool salvaLocalmente = false}) async {
  final pdf = pw.Document();

  final base = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final gara = (dati['gara'] ?? {}) as Map<String, dynamic>;

  // Load logo from assets if available
  final Uint8List? logoBytes = await _loadAssetSafe('assets/logo.png');
  final pw.ImageProvider? logoImage =
      logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  final cronos = (dati['cronometristi'] ?? []) as List;
  final apparecchiature = (dati['apparecchiature'] ?? []) as List;
  final danni = (dati['danni'] ?? '') as String;
  final allegati = (dati['allegati'] ?? []) as List;
  final direttore = (gara['dsc'] ?? '').toString().trim();

  final contenuto = <pw.Widget>[
    _sezioneGara(gara, base, bold),
    pw.SizedBox(height: 16),
    _sezioneCronometristi(cronos, base, bold),
    pw.SizedBox(height: 16),
    _sezioneApparecchiatura(apparecchiature, base, bold),
    pw.SizedBox(height: 16),
    _sezioneDanni(danni, base, bold),
  ];

  if (allegati.isNotEmpty) {
    contenuto.addAll([
      pw.SizedBox(height: 16),
      _sezioneAllegati(allegati),
    ]);
  }

  if (direttore.isNotEmpty) {
    contenuto.addAll([
      pw.SizedBox(height: 16),
      _sezioneDirettore(direttore, base, bold),
    ]);
  }

  pdf.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        margin: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      ),
      header: (context) => _header(bold, logo: logoImage),
      footer: (context) =>
          _footer(base, context.pageNumber, context.pagesCount),
      build: (context) => contenuto,
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final String nomeGara = ((dati['gara'] ?? {})['nome'] ?? 'Rapporto')
      .toString()
      .replaceAll(' ', '');
  final String dataFile = ((dati['gara'] ?? {})['dataDa'] ?? '00000000')
      .toString()
      .replaceAll('-', '');

  final String nomeFile = '${dataFile}_$nomeGara.pdf';
  final file = File('${dir.path}/$nomeFile');
  await file.writeAsBytes(await pdf.save());
  return file;
}

// ===== Sezioni =====
pw.Widget _sezioneGara(Map<String, dynamic> gara, pw.Font base, pw.Font bold) {
  String fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  final nome = (gara['nome'] ?? '').toString();
  final organizzatore = (gara['organizzatore'] ?? '').toString();
  final sport = (gara['sport'] ?? '').toString();
  final luogo = (gara['luogo'] ?? '').toString();
  final dataDa = fmt(gara['dataDa']?.toString());
  final dataA = fmt(gara['dataA']?.toString());
  final dsc = (gara['dsc'] ?? '').toString();

  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            text: '',
            children: [
              pw.TextSpan(
                  text: '$label: ',
                  style: pw.TextStyle(font: bold, fontSize: 11)),
              pw.TextSpan(
                  text: value.isEmpty ? '-' : value,
                  style: pw.TextStyle(font: base, fontSize: 11)),
            ],
          ),
        ),
      );

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _tableAltRowColor,
      border: pw.Border.all(color: _tableBorderColor),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        infoRow('Gara', nome),
        infoRow('Organizzatore', organizzatore),
        infoRow('Sport', sport),
        infoRow('Luogo', luogo),
        infoRow('Data da', dataDa),
        infoRow('Data a', dataA),
        if (dsc.isNotEmpty) infoRow('DSC', dsc),
      ],
    ),
  );
}

pw.Widget _sezioneCronometristi(List elenco, pw.Font base, pw.Font bold) {
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
  double totOre = 0, totKm = 0, totSpese = 0;
  for (final c in elenco) {
    final giorni = (c['giorni'] as List?) ?? [];
    final ore = sum(giorni, 'ore');
    final km = sum(giorni, 'km');
    final spese = sum(giorni, 'spese');
    totOre += ore;
    totKm += km;
    totSpese += spese;
    rows.add([
      (c['nome'] ?? '').toString(),
      ore.toStringAsFixed(1),
      km.toStringAsFixed(1),
      spese.toStringAsFixed(2),
      (c['segreteria'] ?? '').toString(),
      (c['note'] ?? '').toString(),
    ]);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Cronometristi', style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 8),
      _sezioneGiornate(elenco, base, bold),
      pw.SizedBox(height: 4),
      pw.Text('',
          style:
              pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 14),
      pw.Text('Riepilogo cronometristi',
          style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 6),
      _tabellaRiepilogo(rows, totOre, totKm, totSpese, base, bold),
      pw.SizedBox(height: 4),
      pw.Text('* Specificare SI/NO',
          style:
              pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700)),
    ],
  );
}

// Raggruppa per data (yyyy-MM-dd) e stampa una tabella per giornata
pw.Widget _sezioneGiornate(List elenco, pw.Font base, pw.Font bold) {
  final Map<String, List<Map<String, String>>> perData = {};
  for (final c in elenco) {
    final nome = (c['nome'] ?? '').toString();
    final segreteria = (c['segreteria'] ?? '').toString();
    final note = (c['note'] ?? '').toString();
    final giorni = (c['giorni'] as List?) ?? [];
    for (final g in giorni) {
      final dIso = (g['data'] ?? '').toString();
      if (dIso.isEmpty) continue;
      final ore = (g['ore'] ?? '').toString();
      final km = (g['km'] ?? '').toString();
      final spese = (g['spese'] ?? '').toString();
      perData.putIfAbsent(dIso, () => []);
      perData[dIso]!.add({
        'nome': nome,
        'ore': ore,
        'km': km,
        'spese': spese,
        'segreteria': segreteria,
        'note': note,
      });
    }
  }

  final dates = perData.keys.toList()..sort();
  if (dates.isEmpty) {
    return pw.Text('Nessun cronometrista registrato',
        style: pw.TextStyle(font: base));
  }

  final widgets = <pw.Widget>[];
  for (int i = 0; i < dates.length; i++) {
    final d = dates[i];
    final rows = perData[d]!..sort((a, b) => a['nome']!.compareTo(b['nome']!));
    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _tableBorderColor),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const pw.BoxDecoration(color: _tableHeaderColor),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GIORNO ${i + 1}',
                      style: pw.TextStyle(font: bold, fontSize: 12)),
                  pw.Text(_formatDateHuman(d),
                      style: pw.TextStyle(font: base, fontSize: 11)),
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
                5: pw.FlexColumnWidth(2.4),
              },
              children: [
                _giornoHeaderRow(bold),
                ...rows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final rowBg = idx.isOdd ? _tableAltRowColor : null;
                  return pw.TableRow(children: [
                    _giornoCell(r['nome'] ?? '', base, background: rowBg),
                    _giornoCell(_fmtValue(r['ore']), base,
                        center: true, background: rowBg),
                    _giornoCell(_fmtValue(r['km']), base,
                        center: true, background: rowBg),
                    _giornoCell(_fmtValue(r['spese']), base,
                        center: true, background: rowBg),
                    _giornoCell(_fmtValue(r['segreteria']), base,
                        center: true, background: rowBg),
                    _giornoCell(_fmtValue(r['note']), base, background: rowBg),
                  ]);
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
  final categorizzate = _classificaApparecchiature(elenco);
  final cronometri = categorizzate['cronometri'] as List<Map<String, String>>;
  final tabelloni = categorizzate['tabelloni'] as List<Map<String, String>>;
  final varie = categorizzate['varie'] as List<Map<String, String>>;
  final altri = categorizzate['altro'] as List<String>;
  final altText = altri.join(', ');

  final maxRows = math.max(
    1,
    math.max(
      cronometri.length,
      math.max(tabelloni.length, varie.length),
    ),
  );

  pw.Widget headerCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.all(4),
        color: _tableHeaderColor,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: bold, fontSize: 10, color: _tableHeaderTextColor),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
            softWrap: false),
      );

  pw.Widget valueCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: pw.Text(text.isEmpty ? '-' : text,
            style: pw.TextStyle(font: base, fontSize: 10),
            textAlign: pw.TextAlign.left),
      );

  pw.Widget qtyCell(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(font: base, fontSize: 10),
            textAlign: pw.TextAlign.center),
      );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Apparecchiature impiegate',
          style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: _tableBorderColor),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(0.8),
          2: pw.FlexColumnWidth(2.2),
          3: pw.FlexColumnWidth(0.8),
          4: pw.FlexColumnWidth(2.2),
          5: pw.FlexColumnWidth(0.8),
        },
        children: [
          pw.TableRow(children: [
            headerCell('Cronometri'),
            headerCell('N.'),
            headerCell('Tabelloni / Display'),
            headerCell('N.'),
            headerCell('Varie'),
            headerCell('N.'),
          ]),
          for (int i = 0; i < maxRows; i++)
            pw.TableRow(children: [
              valueCell(
                  i < cronometri.length ? cronometri[i]['label'] ?? '' : ''),
              qtyCell(i < cronometri.length ? cronometri[i]['qty'] ?? '' : ''),
              valueCell(
                  i < tabelloni.length ? tabelloni[i]['label'] ?? '' : ''),
              qtyCell(i < tabelloni.length ? tabelloni[i]['qty'] ?? '' : ''),
              valueCell(i < varie.length ? varie[i]['label'] ?? '' : ''),
              qtyCell(i < varie.length ? varie[i]['qty'] ?? '' : ''),
            ]),
        ],
      ),
      if (altText.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: 'Altro: ',
                  style: pw.TextStyle(font: bold, fontSize: 10)),
              pw.TextSpan(
                  text: altText, style: pw.TextStyle(font: base, fontSize: 10)),
            ],
          ),
        ),
      ],
    ],
  );
}

pw.Widget _sezioneDanni(String testo, pw.Font base, pw.Font bold) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Danni / Malfunzionamenti',
          style: pw.TextStyle(font: bold, fontSize: 14)),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(testo.isEmpty ? '-' : testo,
            style: pw.TextStyle(font: base)),
      ),
    ],
  );
}

pw.Widget _sezioneDirettore(
    String direttore, pw.Font base, pw.Font bold) {
  final text = direttore.trim();
  if (text.isEmpty) return pw.SizedBox.shrink();
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text('Direttore Servizio di Cronometraggio: $text',
        style: pw.TextStyle(font: bold, fontSize: 12)),
  );
}

pw.Widget _sezioneAllegati(List allegati) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Allegati fotografici',
          style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 14)),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: allegati.map<pw.Widget>((xfile) {
          final image = pw.MemoryImage(File(xfile.path).readAsBytesSync());
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

pw.Widget _tabellaRiepilogo(List<List<String>> rows, double totOre,
    double totKm, double totSpese, pw.Font base, pw.Font bold) {
  pw.Widget cell(String text,
          {bool header = false,
          bool boldText = false,
          bool center = false,
          PdfColor? background}) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        color: header ? _tableHeaderColor : background,
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: boldText ? bold : base,
                color: header ? _tableHeaderTextColor : PdfColors.black,
                fontSize: 10,
                fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal),
            maxLines: header ? 1 : null,
            softWrap: header ? false : true),
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
      pw.TableRow(children: [
        cell('Nome', header: true, center: true),
        cell('Ore', header: true, center: true),
        cell('Km', header: true, center: true),
        cell('Spese', header: true, center: true),
        cell('Segreteria', header: true, center: true),
        cell('Note', header: true, center: true),
      ]),
      ...rows.asMap().entries.map((entry) {
        final index = entry.key;
        final r = entry.value;
        final rowBg = index.isOdd ? _tableAltRowColor : null;
        return pw.TableRow(children: [
          cell(r[0], background: rowBg),
          cell(r[1], center: true, background: rowBg),
          cell(r[2], center: true, background: rowBg),
          cell(r[3], center: true, background: rowBg),
          cell(r[4], center: true, background: rowBg),
          cell(r[5], background: rowBg),
        ]);
      }),
      pw.TableRow(children: [
        cell('Totali', boldText: true, background: _tableAltRowColor),
        cell(totOre.toStringAsFixed(1),
            boldText: true, center: true, background: _tableAltRowColor),
        cell(totKm.toStringAsFixed(1),
            boldText: true, center: true, background: _tableAltRowColor),
        cell(totSpese.toStringAsFixed(2),
            boldText: true, center: true, background: _tableAltRowColor),
        cell('', boldText: true, background: _tableAltRowColor),
        cell('', boldText: true, background: _tableAltRowColor),
      ]),
    ],
  );
}

Map<String, dynamic> _classificaApparecchiature(List elenco) {
  final cronometri = <Map<String, String>>[];
  final tabelloni = <Map<String, String>>[];
  final varie = <Map<String, String>>[];
  final altri = <String>[];

  for (final voce in elenco) {
    if (voce is! Map) continue;
    final nome = (voce['dispositivo'] ?? '').toString().trim();
    if (nome.isEmpty) continue;
    final qty = (voce['quantita'] ?? '').toString().trim();
    final key = nome.toLowerCase();

    Map<String, String> entry() =>
        {'label': nome, 'qty': qty.isEmpty ? '-' : qty};

    if (_cronometriDevices.contains(key)) {
      cronometri.add(entry());
    } else if (_tabelloniDevices.contains(key)) {
      tabelloni.add(entry());
    } else if (_varieDevices.contains(key)) {
      varie.add(entry());
    } else {
      altri.add(qty.isEmpty ? nome : '$nome ($qty)');
    }
  }

  cronometri.sort((a, b) => a['label']!.compareTo(b['label']!));
  tabelloni.sort((a, b) => a['label']!.compareTo(b['label']!));
  varie.sort((a, b) => a['label']!.compareTo(b['label']!));
  altri.sort();

  return {
    'cronometri': cronometri,
    'tabelloni': tabelloni,
    'varie': varie,
    'altro': altri,
  };
}

pw.TableRow _giornoHeaderRow(pw.Font bold) => pw.TableRow(children: [
      _giornoCell('Cronometrista', bold, header: true),
      _giornoCell('Ore', bold, header: true, center: true),
      _giornoCell('Km', bold, header: true, center: true),
      _giornoCell('Spese', bold, header: true, center: true),
      _giornoCell('Segreteria', bold, header: true, center: true),
      _giornoCell('Note', bold, header: true),
    ]);

pw.Widget _giornoCell(String text, pw.Font font,
        {bool header = false, bool center = false, PdfColor? background}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      color: background ?? (header ? _tableHeaderColor : null),
      child: pw.Text(text,
          style: pw.TextStyle(
              font: font,
              color: header ? _tableHeaderTextColor : PdfColors.black,
              fontSize: 10,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal),
          maxLines: header ? 1 : null,
          softWrap: header ? false : true),
    );

String _formatDateHuman(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return iso;
  }
}

String _fmtValue(String? value) {
  if (value == null || value.isEmpty) return '-';
  return value;
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
              pw.Text('ASD Cronometristi Valtellinesi',
                  style: pw.TextStyle(font: bold, fontSize: 12)),
              pw.Text('Piazzale Valgoi, 5',
                  style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10)),
              pw.Text('23100 - Sondrio',
                  style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10)),
            ],
          ),
          if (logo != null)
            pw.Container(
              width: 60,
              height: 60,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 60,
              height: 60,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
                borderRadius: pw.BorderRadius.circular(30),
              ),
              child: pw.Text('LOGO',
                  style: pw.TextStyle(font: bold, fontSize: 10)),
            ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text('RAPPORTO DI SERVIZIO',
            style: pw.TextStyle(font: bold, fontSize: 18)),
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.grey400),
    ],
  );
}

pw.Widget _footer(pw.Font base, int page, int pages) {
  final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text('Generato: ' + now,
          style:
              pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700)),
      pw.Text('Pagina ' + page.toString() + ' di ' + pages.toString(),
          style:
              pw.TextStyle(font: base, fontSize: 9, color: PdfColors.grey700)),
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
