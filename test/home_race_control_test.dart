import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
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

Map<String, dynamic> _racePage() => {
      'id': 'race-1',
      'properties': {
        NotionRaceProperties.title: {
          'title': [
            {'plain_text': 'Gara singola'}
          ],
        },
        NotionRaceProperties.date: {
          'date': {'start': '2026-08-12', 'end': null},
        },
        NotionRaceProperties.status: {
          'status': {'name': RaceStatuses.designationSent},
        },
        NotionRaceProperties.designatedTimekeepers: {
          'relation': [
            {'id': 'user-1'}
          ],
        },
        NotionRaceProperties.serviceManager: {'relation': <dynamic>[]},
        NotionRaceProperties.secretaryPc: {'relation': <dynamic>[]},
      },
    };

void main() {
  testWidgets('single Race Control card lays out in a scrolling home page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loggedUser: const {'id': 'user-1'},
          onLogout: () {},
          notionService: _FakeNotionService([_racePage()]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('RACE CONTROL'), findsOneWidget);
    expect(find.text('Gara singola'), findsOneWidget);
    expect(find.text('APRI DETTAGLI GARA'), findsOneWidget);
    expect(find.text('Impostazioni'), findsNothing);
    expect(find.byTooltip('Impostazioni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
