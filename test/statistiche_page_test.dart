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
          'date': {'start': '2026-06-15', 'end': null},
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = find.byType(DropdownButtonFormField<String>);
      await Scrollable.ensureVisible(
        tester.element(selector),
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mario Rossi').last);
      await tester.pumpAndSettle();

      expect(find.text('Servizi di Mario Rossi'), findsOneWidget);
      expect(find.text('Servizi per sport'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );
}
