import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
import 'package:rapporto_servizio/pages/statistiche_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';

class _FakeNotionService extends NotionService {
  _FakeNotionService(this.rows, this.names) : super(databaseId: 'test');

  final List<Map<String, dynamic>> rows;
  final Map<String, String> names;

  @override
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
    bool forceRefresh = false,
  }) async =>
      rows;

  @override
  Future<String> fetchNameFromPage(String pageId) async => names[pageId] ?? '';
}

Map<String, dynamic> _adminUser() => {
      'id': 'admin-id',
      'properties': {
        'ADMIN': {'checkbox': true},
      },
    };

Map<String, dynamic> _race({
  required String id,
  required String sport,
  String date = '2026-06-15',
  String? status = RaceStatuses.sicWinOk,
  List<String> timekeepers = const [],
  List<String> serviceManagers = const [],
  List<String> dataOperators = const [],
}) =>
    {
      'id': id,
      'properties': {
        NotionRaceProperties.title: {
          'title': [
            {'plain_text': 'Gara $id'},
          ],
        },
        NotionRaceProperties.date: {
          'date': {'start': date, 'end': null},
        },
        if (status != null)
          NotionRaceProperties.status: {
            'status': {'name': status},
          },
        NotionRaceProperties.designatedTimekeepers: {
          'relation': timekeepers.map((id) => {'id': id}).toList(),
        },
        NotionRaceProperties.serviceManager: {
          'relation': serviceManagers.map((id) => {'id': id}).toList(),
        },
        NotionRaceProperties.secretaryPc: {
          'relation': dataOperators.map((id) => {'id': id}).toList(),
        },
        'SPORT': {
          'select': {'name': sport},
        },
      },
    };

void main() {
  testWidgets('la voce Statistiche mostra solo i dati personali',
      (tester) async {
    final notion = _FakeNotionService(
      [
        _race(id: '1', sport: 'Sci', timekeepers: const ['admin-id']),
      ],
      const {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatistichePage(
          loggedUser: _adminUser(),
          notionService: notion,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Designazioni come crono'), findsOneWidget);
    expect(find.text('Servizi per cronometrista'), findsNothing);
    expect(find.textContaining('Gare totali per sport'), findsNothing);
  });

  testWidgets(
    'admin selects a timekeeper and sees unique services grouped by sport',
    (tester) async {
      final notion = _FakeNotionService(
        [
          _race(id: '1', sport: 'Sci', timekeepers: const ['person-1']),
          _race(
            id: '2',
            sport: 'Nuoto',
            timekeepers: const ['person-1'],
            serviceManagers: const ['person-1'],
          ),
          _race(
            id: '3',
            sport: 'Ciclismo',
            dataOperators: const ['person-2'],
          ),
          _race(
            id: '4',
            sport: 'Pattinaggio',
            status: 'SICWIN pending',
            timekeepers: const ['person-1'],
          ),
          _race(
            id: '5',
            sport: 'Corsa',
          ),
        ],
        const {
          'person-1': 'Mario Rossi',
          'person-2': 'Anna Bianchi',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatistichePage(
            loggedUser: _adminUser(),
            notionService: notion,
            adminOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = find.byType(DropdownButtonFormField<String>);
      await tester.dragUntilVisible(
        selector,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await Scrollable.ensureVisible(
        tester.element(selector),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mario Rossi').last);
      await tester.pumpAndSettle();

      expect(find.text('Servizi di Mario Rossi'), findsOneWidget);
      expect(find.text('Servizi per sport'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('selected-person-sport-statistics'),
          ),
          matching: find.text('Pattinaggio'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'association statistics exclude non-SICWIN OK races and their people',
    (tester) async {
      final notion = _FakeNotionService(
        [
          _race(
            id: 'eligible-sci',
            sport: 'Sci',
            timekeepers: const ['eligible-person'],
          ),
          _race(id: 'eligible-swim', sport: 'Nuoto'),
          _race(
            id: 'pending-cycling',
            sport: 'Ciclismo',
            status: 'SICWIN pending',
            timekeepers: const ['pending-person'],
          ),
          _race(
            id: 'missing-running',
            sport: 'Corsa',
            status: null,
            timekeepers: const ['missing-person'],
          ),
        ],
        const {
          'eligible-person': 'Persona valida',
          'pending-person': 'Persona pending',
          'missing-person': 'Persona senza stato',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatistichePage(
            loggedUser: _adminUser(),
            notionService: notion,
            adminOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final associationBreakdown = find.byKey(
        const ValueKey('association-sport-statistics'),
      );
      await tester.scrollUntilVisible(
        associationBreakdown,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gare totali per sport (2)'), findsOneWidget);
      expect(
        find.descendant(of: associationBreakdown, matching: find.text('Sci')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: associationBreakdown,
          matching: find.text('Nuoto'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: associationBreakdown,
          matching: find.text('Ciclismo'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: associationBreakdown,
          matching: find.text('Corsa'),
        ),
        findsNothing,
      );

      final selector = find.byType(DropdownButtonFormField<String>);
      await Scrollable.ensureVisible(
        tester.element(selector),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('Persona valida').last, findsOneWidget);
      expect(find.text('Persona pending'), findsNothing);
      expect(find.text('Persona senza stato'), findsNothing);
    },
  );

  testWidgets(
    'personal totals and year/sport breakdowns use only eligible participation',
    (tester) async {
      final notion = _FakeNotionService(
        [
          _race(
            id: 'eligible-2026',
            sport: 'Sci',
            timekeepers: const ['admin-id'],
          ),
          _race(
            id: 'eligible-2025',
            sport: 'Rally',
            date: '2025-07-20',
            timekeepers: const ['admin-id'],
          ),
          _race(
            id: 'pending-2024',
            sport: 'Nuoto',
            date: '2024-08-10',
            status: 'SICWIN pending',
            timekeepers: const ['admin-id'],
          ),
          _race(
            id: 'eligible-unassigned',
            sport: 'Corsa',
          ),
          _race(
            id: 'eligible-dsc',
            sport: 'Biathlon',
            serviceManagers: const ['admin-id'],
          ),
          _race(
            id: 'eligible-data-role',
            sport: 'Slittino',
            dataOperators: const ['admin-id'],
          ),
          _race(
            id: 'missing-data-role',
            sport: 'Ciclismo',
            status: null,
            dataOperators: const ['admin-id'],
          ),
        ],
        const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatistichePage(
            loggedUser: _adminUser(),
            notionService: notion,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Hai 1 designazioni da crono nel 2026'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('personal-timekeeper-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('personal-service-manager-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('personal-data-operator-count')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      final sportBreakdown = find.byKey(
        const ValueKey('personal-sport-statistics'),
      );
      await tester.scrollUntilVisible(
        sportBreakdown,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: sportBreakdown, matching: find.text('Sci')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sportBreakdown, matching: find.text('Nuoto')),
        findsNothing,
      );

      final yearBreakdown = find.byKey(
        const ValueKey('personal-year-statistics'),
      );
      await tester.scrollUntilVisible(
        yearBreakdown,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: yearBreakdown, matching: find.text('2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: yearBreakdown, matching: find.text('2025')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: yearBreakdown, matching: find.text('2024')),
        findsNothing,
      );
      expect(find.text('Ciclismo'), findsNothing);
    },
  );
}
