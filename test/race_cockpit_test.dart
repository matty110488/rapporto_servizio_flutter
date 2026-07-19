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

void main() {
  testWidgets('cockpit renders pass and operational information on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gara = Gara(
      id: '123456781234123412341234567890ab',
      titolo: 'Trofeo Test Technology',
      sport: 'Sci alpino',
      dataGara: '2026-12-20',
      dataGaraFine: '',
      localita: 'Chiesa in Valmalenco',
      sitoGara: 'Pista Campolungo',
      organizzatore: 'Sci Club +39 333 1234567',
      idSicWin: '',
      dataRichiesta: '',
      kronosIds: const ['crono-id'],
      dscIds: const ['dsc-id'],
      pcSegreteriaIds: const ['pc-id'],
      apparecchiature: const ['Finish Lynx', 'Tabellone'],
      tipologia: 'C + S',
      status: 'DESIGNAZIONE INVIATA',
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.2),
          ),
          child: child!,
        ),
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cockpit gara'), findsOneWidget);
    expect(find.text('RACE CONTROL'), findsOneWidget);
    expect(find.text('Trofeo Test Technology'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Il tuo pass'), 300);
    await tester.pumpAndSettle();

    expect(find.text('DESIGNAZIONE · SERVICE PASS'), findsOneWidget);
    expect(find.text('Cronometrista'), findsOneWidget);
    expect(find.text('Condividi o salva pass'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
