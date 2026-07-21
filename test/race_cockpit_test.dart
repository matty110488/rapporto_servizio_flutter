import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/pages/dettaglio_gara.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeNotionService extends NotionService {
  _FakeNotionService() : super(databaseId: 'test');

  @override
  Future<String> fetchNameFromPage(String pageId) async => switch (pageId) {
        'dsc-id' => 'Mario Responsabile',
        'crono-id' => 'Luca Cronometrista',
        'pc-id' => 'Anna Segreteria',
        _ => '',
      };
}

Gara _gara({required String organizzatore}) => Gara(
      id: '123456781234123412341234567890ab',
      titolo: 'Trofeo Test Technology',
      sport: 'Sci alpino',
      dataGara: '2026-12-20',
      dataGaraFine: '',
      localita: 'Chiesa in Valmalenco',
      sitoGara: 'Pista Campolungo',
      organizzatore: organizzatore,
      idSicWin: '',
      dataRichiesta: '',
      kronosIds: const ['crono-id'],
      dscIds: const ['dsc-id'],
      pcSegreteriaIds: const ['pc-id'],
      apparecchiature: const ['Finish Lynx', 'Tabellone'],
      tipologia: 'C + S',
      status: 'DESIGNAZIONE INVIATA',
    );

Widget _app(Gara gara) => MaterialApp(
      home: DettaglioGara(
        gara: gara,
        loggedUser: const {
          'id': 'crono-id',
          'properties': {
            'USERNAME': {
              'type': 'rich_text',
              'rich_text': [
                {'plain_text': 'Luca Cronometrista'}
              ],
            },
          },
        },
        notionService: _FakeNotionService(),
      ),
    );

void main() {
  testWidgets('cockpit keeps Race Control and standard operational sections',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(_gara(organizzatore: 'Sci Club +39 333 1234567')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cockpit gara'), findsOneWidget);
    expect(find.text('RACE CONTROL'), findsOneWidget);
    expect(find.text('Trofeo Test Technology'), findsOneWidget);
    expect(find.text('Azioni rapide'), findsOneWidget);
    expect(find.text('INDICAZIONI'), findsOneWidget);
    expect(find.text('ORGANIZZATORE'), findsOneWidget);
    expect(find.text('Sci Club'), findsOneWidget);
    expect(find.text('CHIAMA ORGANIZZATORE'), findsOneWidget);
    expect(find.text('+39 333 1234567'), findsOneWidget);

    expect(find.text('Avanzamento missione'), findsNothing);
    expect(find.text('Il tuo pass'), findsNothing);
    expect(find.text('Mostra pass'), findsNothing);
    expect(find.text('Apparecchiatura prevista'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer call is hidden when no phone number is provided',
      (tester) async {
    await tester.pumpWidget(_app(_gara(organizzatore: 'Sci Club Valtellina')));
    await tester.pumpAndSettle();

    expect(find.text('INDICAZIONI'), findsOneWidget);
    expect(find.text('ORGANIZZATORE'), findsOneWidget);
    expect(find.text('Sci Club Valtellina'), findsOneWidget);
    expect(find.text('CHIAMA ORGANIZZATORE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
