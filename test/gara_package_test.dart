import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/models/gara_package.dart';

Gara gara({
  required String id,
  required String title,
  required String date,
  String endDate = '',
  String packageId = '',
  String place = 'Sondrio',
}) =>
    Gara(
      id: id,
      titolo: title,
      sport: 'Nuoto',
      dataGara: date,
      dataGaraFine: endDate,
      localita: place,
      sitoGara: '',
      organizzatore: 'Associazione',
      idSicWin: packageId,
      dataRichiesta: '',
      kronosIds: const [],
      dscIds: const [],
      pcSegreteriaIds: const [],
      apparecchiature: const [],
      tipologia: '',
      status: 'GARA COMPLETATA',
    );

void main() {
  test('groups confirmed packages by ID SIC WIN', () {
    final packages = buildGaraPackages([
      gara(
        id: 'one',
        title: 'Trofeo Valtellina - Sabato',
        date: '2026-08-12',
        packageId: 'PK-42',
      ),
      gara(
        id: 'two',
        title: 'Trofeo Valtellina - Domenica',
        date: '2026-08-13',
        packageId: 'PK-42',
      ),
    ]);

    expect(packages, hasLength(1));
    expect(packages.single.isConfirmedPackage, isTrue);
    expect(packages.single.title, 'Trofeo Valtellina');
    expect(packages.single.stableKey, 'package:PK-42');
  });

  test('preserves only real package dates, including gaps', () {
    final package = buildGaraPackages([
      gara(id: 'one', title: 'Meeting Alpino Sabato', date: '2026-08-12'),
      gara(id: 'two', title: 'Meeting Alpino Domenica', date: '2026-08-14'),
    ]).single;

    expect(package.suggested, isTrue);
    expect(
      package.activeDates
          .map((date) => date.toIso8601String().substring(0, 10)),
      ['2026-08-12', '2026-08-14'],
    );
  });

  test('expands an explicit date range from one database row', () {
    final package = buildGaraPackages([
      gara(
        id: 'one',
        title: 'Gara continuativa',
        date: '2026-09-01',
        endDate: '2026-09-03',
      ),
    ]).single;

    expect(package.activeDates, hasLength(3));
  });
}
