import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
import 'package:rapporto_servizio/models/admin_dashboard_data.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/pages/admin_dashboard_page.dart';
import 'package:rapporto_servizio/pages/home_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotionService extends NotionService {
  _FakeNotionService(this.rows) : super(databaseId: 'test');

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
    bool forceRefresh = false,
  }) async =>
      rows;
}

Map<String, dynamic> _adminUser() => {
      'id': 'admin-1',
      'properties': {
        'ADMIN': {'checkbox': true},
      },
    };

Map<String, dynamic> _racePage({
  required String id,
  required String title,
  required DateTime date,
  required String status,
  bool withDsc = true,
  bool withTimekeeper = true,
  String sport = 'Sci',
  String location = 'Bormio',
}) =>
    {
      'id': id,
      'properties': {
        NotionRaceProperties.title: {
          'title': [
            {'plain_text': title}
          ],
        },
        NotionRaceProperties.date: {
          'date': {'start': _isoDate(date), 'end': null},
        },
        NotionRaceProperties.status: {
          'status': {'name': status},
        },
        NotionRaceProperties.designatedTimekeepers: {
          'relation': withTimekeeper
              ? [
                  {'id': 'user-1'}
                ]
              : <dynamic>[],
        },
        NotionRaceProperties.serviceManager: {
          'relation': withDsc
              ? [
                  {'id': 'dsc-1'}
                ]
              : <dynamic>[],
        },
        NotionRaceProperties.secretaryPc: {'relation': <dynamic>[]},
        'SPORT': {
          'select': {'name': sport},
        },
        NotionRaceProperties.location: {
          'rich_text': [
            {'plain_text': location}
          ],
        },
      },
    };

String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Gara _gara({
  required String id,
  required DateTime date,
  required String status,
  List<String> dsc = const ['dsc'],
  List<String> timekeepers = const ['kronos'],
  String sport = 'Sci',
  String location = 'Bormio',
}) {
  return Gara(
    id: id,
    titolo: 'Gara $id',
    sport: sport,
    dataGara: _isoDate(date),
    dataGaraFine: '',
    localita: location,
    sitoGara: '',
    organizzatore: '',
    idSicWin: '',
    dataRichiesta: '',
    kronosIds: timekeepers,
    dscIds: dsc,
    pcSegreteriaIds: const [],
    apparecchiature: const [],
    tipologia: '',
    status: status,
  );
}

void main() {
  test('calcola le criticità operative senza contare rapportini archiviati',
      () {
    final now = DateTime(2026, 8, 10);
    final data = AdminDashboardData.fromGare(
      [
        _gara(
          id: 'future',
          date: now.add(const Duration(days: 5)),
          status: RaceStatuses.designationSent,
          dsc: const [],
        ),
        _gara(
          id: 'past',
          date: now.subtract(const Duration(days: 3)),
          status: RaceStatuses.completed,
        ),
        _gara(
          id: 'archived',
          date: now.subtract(const Duration(days: 7)),
          status: RaceStatuses.reportReceived,
        ),
      ],
      now: now,
    );

    expect(data.upcomingRaces.map((gara) => gara.id), ['future']);
    expect(data.incompleteDesignations.map((gara) => gara.id), ['future']);
    expect(data.pendingReports.map((gara) => gara.id), ['past']);
    expect(
      data.attentionItems.map((item) => item.gara.id),
      containsAll(['future', 'past']),
    );
    expect(
      data.attentionItems.map((item) => item.gara.id),
      isNot(contains('archived')),
    );
    expect(
      data.attentionItems
          .firstWhere((item) => item.gara.id == 'future')
          .timingLabel,
      'Scade tra 5 giorni',
    );
    expect(
      data.attentionItems
          .firstWhere((item) => item.gara.id == 'past')
          .timingLabel,
      'In ritardo da 3 giorni',
    );
  });

  testWidgets('mostra riepilogo e criticità agli admin', (tester) async {
    final today = DateTime.now();
    final rows = [
      _racePage(
        id: 'future',
        title: 'Gara da coprire',
        date: today.add(const Duration(days: 5)),
        status: RaceStatuses.designationSent,
        withDsc: false,
      ),
      _racePage(
        id: 'past',
        title: 'Gara senza rapportino',
        date: today.subtract(const Duration(days: 3)),
        status: RaceStatuses.completed,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          loggedUser: _adminUser(),
          notionService: _FakeNotionService(rows),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Centro di controllo Admin'), findsOneWidget);
    expect(find.text('Azioni rapide'), findsOneWidget);
    expect(find.text('Simula il costo di una gara'), findsOneWidget);
    expect(find.text('Designazioni incomplete'), findsOneWidget);
    expect(find.text('Rapportini da ricevere'), findsOneWidget);
    expect(find.text('Gara da coprire'), findsWidgets);
    expect(find.textContaining('Mancano DSC'), findsOneWidget);
    expect(find.text('Gara senza rapportino'), findsOneWidget);
    expect(find.text('Scade tra 5 giorni'), findsOneWidget);
    expect(find.text('In ritardo da 3 giorni'), findsOneWidget);

    await tester.tap(find.text('Rapportini 1'));
    await tester.pump();
    expect(find.textContaining('Mancano DSC'), findsNothing);
    expect(
        find.textContaining('Rapportino non ancora ricevuto'), findsOneWidget);

    await tester.tap(find.text('Designazioni 1'));
    await tester.pump();
    expect(find.textContaining('Mancano DSC'), findsOneWidget);
    expect(find.textContaining('Rapportino non ancora ricevuto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la dashboard admin resta leggibile su mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardPage(
          loggedUser: _adminUser(),
          notionService: _FakeNotionService(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PANORAMICA OPERATIVA'), findsOneWidget);
    expect(find.text('Preventivi'), findsOneWidget);
    expect(find.text('Controlla costi e consuntivi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('il menu admin compare solo agli amministratori', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notion = _FakeNotionService(const []);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loggedUser: _adminUser(),
          onLogout: () {},
          notionService: notion,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Centro di controllo Admin'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loggedUser: const {'id': 'user-1', 'properties': <String, dynamic>{}},
          onLogout: () {},
          notionService: notion,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Centro di controllo Admin'), findsNothing);
  });
}
