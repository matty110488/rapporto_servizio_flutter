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
  test('Halloween decorations are limited to the seasonal window', () {
    expect(shouldShowHalloweenDecorations(DateTime(2026, 10, 19)), isFalse);
    expect(shouldShowHalloweenDecorations(DateTime(2026, 10, 20)), isTrue);
    expect(shouldShowHalloweenDecorations(DateTime(2026, 10, 31)), isTrue);
    expect(shouldShowHalloweenDecorations(DateTime(2026, 11, 2)), isTrue);
    expect(shouldShowHalloweenDecorations(DateTime(2026, 11, 3)), isFalse);
  });

  testWidgets('single Race Control card lays out in a scrolling home page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          loggedUser: const {'id': 'user-1'},
          onLogout: () {},
          notionService: _FakeNotionService([_racePage()]),
          now: () => DateTime(2026, 10, 26),
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

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF004E9A));
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 2);
    expect(
      appBar.systemOverlayStyle?.statusBarColor,
      const Color(0xFF004E9A),
    );
    expect(
      appBar.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(find.byKey(const ValueKey('halloween-banner')), findsOneWidget);
    expect(find.text('Dolcetto o cronometro?'), findsOneWidget);
  });
}
