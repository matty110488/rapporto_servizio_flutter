import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/models/race_statistics.dart';

Gara _race(String status) {
  return Gara(
    id: status,
    titolo: 'Gara',
    sport: 'Sci',
    dataGara: '2026-01-01',
    dataGaraFine: '',
    localita: '',
    sitoGara: '',
    organizzatore: '',
    idSicWin: '',
    dataRichiesta: '',
    kronosIds: const [],
    dscIds: const [],
    pcSegreteriaIds: const [],
    apparecchiature: const [],
    tipologia: '',
    status: status,
  );
}

void main() {
  test('a missing STATUS field cannot fall back to another select', () {
    final race = Gara.fromNotion({
      'id': 'missing-status',
      'properties': {
        NotionRaceProperties.title: {
          'title': [
            {'plain_text': 'Gara senza stato'},
          ],
        },
        NotionRaceProperties.date: {
          'date': {'start': '2026-01-01', 'end': null},
        },
        'SPORT': {
          'type': 'select',
          'select': {'name': RaceStatuses.sicWinOk},
        },
      },
    });

    expect(race.status, isEmpty);
    expect(isRaceEligibleForStatistics(race), isFalse);
  });

  test('statistics eligibility accepts only the exact SICWIN OK status', () {
    expect(
      isRaceEligibleForStatistics(_race(RaceStatuses.sicWinOk)),
      isTrue,
    );

    for (final status in [
      '',
      'SICWIN pending',
      'SICWIN error',
      'GARA COMPLETATA',
      'COMPLETED',
      'CANCELLED',
      'SICWIN OK ',
      'sicwin ok',
    ]) {
      expect(
        isRaceEligibleForStatistics(_race(status)),
        isFalse,
        reason: 'Unexpectedly accepted status "$status"',
      );
    }
  });

  test('mixed race data retains only SICWIN OK entries', () {
    final races = [
      _race(RaceStatuses.sicWinOk),
      _race('SICWIN pending'),
      _race('SICWIN error'),
      _race(''),
    ];

    final eligible = eligibleRacesForStatistics(races);

    expect(eligible, hasLength(1));
    expect(eligible.single.status, RaceStatuses.sicWinOk);
  });
}
