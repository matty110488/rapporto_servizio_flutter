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

  @override
  Future<NotionPersonContact> fetchPersonContactFromPage(String pageId) async {
    if (pageId == 'dsc-id') {
      return const NotionPersonContact(
        name: 'Mario Responsabile',
        phone: '+39 333 7654321',
      );
    }
    return const NotionPersonContact(name: '', phone: '');
  }
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

Widget _app(
  Gara gara, {
  String userId = 'crono-id',
  bool admin = false,
}) =>
    MaterialApp(
      home: DettaglioGara(
        gara: gara,
        loggedUser: {
          'id': userId,
          'properties': {
            'USERNAME': {
              'type': 'rich_text',
              'rich_text': const [
                {'plain_text': 'Utente Test'}
              ],
            },
            if (admin) 'ADMIN': {'checkbox': true},
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
    expect(find.text('CHIAMA ORGANIZZATORE'), findsNothing);
    expect(find.text('Utente Test'), findsOneWidget);
    expect(find.text('Cronometrista'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('TELEFONA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Equipe di Cronometraggio'), findsOneWidget);
    expect(find.text('TELEFONA'), findsOneWidget);
    expect(find.text('WHATSAPP'), findsOneWidget);

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

  testWidgets('race DSC can call the organizer', (tester) async {
    await tester.pumpWidget(
      _app(
        _gara(organizzatore: 'Sci Club +39 333 1234567'),
        userId: 'dsc-id',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHIAMA ORGANIZZATORE'), findsOneWidget);
    expect(find.text('+39 333 1234567'), findsOneWidget);
  });

  testWidgets('admin can call the organizer', (tester) async {
    await tester.pumpWidget(
      _app(
        _gara(organizzatore: 'Sci Club +39 333 1234567'),
        userId: 'admin-id',
        admin: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHIAMA ORGANIZZATORE'), findsOneWidget);
  });

  testWidgets('viewer identity is hidden from Race Control', (tester) async {
    await tester.pumpWidget(
      _app(
        _gara(organizzatore: 'Sci Club +39 333 1234567'),
        userId: 'viewer-id',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RACE CONTROL'), findsOneWidget);
    expect(find.text('Utente Test'), findsNothing);
    expect(find.text('Visualizzazione'), findsNothing);
  });
}
