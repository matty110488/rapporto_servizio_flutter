import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
import 'package:rapporto_servizio/pages/home_page.dart';
import 'package:rapporto_servizio/services/app_preferences_service.dart';
import 'package:rapporto_servizio/services/notion_service.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';
import 'package:rapporto_servizio/widgets/app_ui.dart';
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

class _FailingNotionService extends NotionService {
  _FailingNotionService() : super(databaseId: 'test');

  @override
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
    bool forceRefresh = false,
  }) =>
      Future.error(StateError('offline'));
}

class _PendingNotionService extends NotionService {
  _PendingNotionService(this.completer) : super(databaseId: 'test');
  final Completer<List<Map<String, dynamic>>> completer;

  @override
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
    bool forceRefresh = false,
  }) =>
      completer.future;
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) pushes++;
  }
}

Map<String, dynamic> _racePage({
  required String id,
  required String title,
  required String date,
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
          'date': {'start': date, 'end': null},
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
        'SPORT': {
          'select': {'name': 'Hockey'},
        },
        NotionRaceProperties.location: {
          'rich_text': [
            {'plain_text': 'Madesimo'}
          ],
        },
      },
    };

const _user = {
  'id': 'user-1',
  'properties': {
    'NOME': {
      'type': 'rich_text',
      'rich_text': [
        {'plain_text': 'Mattia'}
      ],
    },
  },
};

Widget _home({
  required NotionService notion,
  VoidCallback? onLogout,
  int unread = 0,
  double textScale = 1,
  NavigatorObserver? navigatorObserver,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
    builder: (context, child) => ValtellinaBackground(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
    home: HomePage(
      key: UniqueKey(),
      loggedUser: _user,
      onLogout: onLogout ?? () {},
      notionService: notion,
      initialUnreadNotifications: unread,
    ),
  );
}

Future<void> _pumpLoadedHome(
  WidgetTester tester, {
  required List<Map<String, dynamic>> rows,
  VoidCallback? onLogout,
  int unread = 0,
  double textScale = 1,
  NavigatorObserver? navigatorObserver,
}) async {
  await tester.pumpWidget(
    _home(
      notion: _FakeNotionService(rows),
      onLogout: onLogout,
      unread: unread,
      textScale: textScale,
      navigatorObserver: navigatorObserver,
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home without designations links to the calendar',
      (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: const [],
      navigatorObserver: observer,
    );

    expect(find.text('Nessuna designazione in programma'), findsOneWidget);
    expect(find.text('Vai al calendario'), findsOneWidget);
    await tester.tap(find.text('Vai al calendario'));
    expect(observer.pushes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single Race Control card opens race details', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: [
        _racePage(
          id: 'race-1',
          title: 'Gara singola con un titolo completo e leggibile',
          date: '2026-11-12',
        ),
      ],
      navigatorObserver: observer,
    );

    expect(find.text('Le tue prossime attività'), findsOneWidget);
    expect(find.text('Race Control'), findsOneWidget);
    expect(find.textContaining('Gara singola'), findsOneWidget);
    expect(find.text('Hockey · Madesimo'), findsOneWidget);
    expect(find.text('Apri dettagli gara'), findsOneWidget);
    final detailsButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apri dettagli gara'),
    );
    expect(
      detailsButton.style?.backgroundColor?.resolve({}),
      AppColors.primarySoft,
    );
    expect(
      detailsButton.style?.foregroundColor?.resolve({}),
      AppColors.primary,
    );
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Apri dettagli gara'))
          .height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('Apri dettagli gara'));
    expect(observer.pushes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple designations keep the Race Control carousel',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: [
        _racePage(id: 'one', title: 'Prima gara', date: '2026-11-12'),
        _racePage(id: 'two', title: 'Seconda gara', date: '2026-11-13'),
      ],
    );

    final carousel = find.byKey(const ValueKey('race-control-carousel'));
    expect(carousel, findsOneWidget);
    final pageView = tester.widget<PageView>(carousel);
    expect(pageView.controller?.viewportFraction, 0.87);
    expect(find.text('1/2'), findsOneWidget);
    final viewportRect = tester.getRect(carousel);
    final secondCard = find.ancestor(
      of: find.text('Seconda gara'),
      matching: find.byType(AppCard),
    );
    final secondCardRect = tester.getRect(secondCard.first);
    final visibleShare =
        (viewportRect.right - secondCardRect.left) / secondCardRect.width;
    expect(visibleShare, inInclusiveRange(0.12, 0.15));
    await tester.drag(
      carousel,
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    final lastCardRect = tester.getRect(secondCard.first);
    expect(lastCardRect.right, closeTo(viewportRect.right, 1));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 393.0, 430.0]) {
    testWidgets('carousel preview fits ${width.toInt()} px with 140% text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpLoadedHome(
        tester,
        textScale: 1.4,
        rows: [
          _racePage(id: 'one', title: 'Prima gara', date: '2026-11-12'),
          _racePage(id: 'two', title: 'Seconda gara', date: '2026-11-13'),
        ],
      );

      final carousel = find.byKey(const ValueKey('race-control-carousel'));
      final viewportRect = tester.getRect(carousel);
      final secondCard = find.ancestor(
        of: find.text('Seconda gara'),
        matching: find.byType(AppCard),
      );
      final secondCardRect = tester.getRect(secondCard.first);
      final visibleShare =
          (viewportRect.right - secondCardRect.left) / secondCardRect.width;
      expect(visibleShare, inInclusiveRange(0.115, 0.155));
      expect(find.text('1/2'), findsOneWidget);

      await tester.drag(carousel, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
      expect(
        tester.getRect(secondCard.first).right,
        closeTo(viewportRect.right, 1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('carousel reaches the last of three designations',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLoadedHome(
      tester,
      textScale: 1.4,
      rows: [
        _racePage(id: 'one', title: 'Prima gara', date: '2026-11-12'),
        _racePage(id: 'two', title: 'Seconda gara', date: '2026-11-13'),
        _racePage(id: 'three', title: 'Terza gara', date: '2026-11-14'),
      ],
    );

    final carousel = find.byKey(const ValueKey('race-control-carousel'));
    final controller = tester.widget<PageView>(carousel).controller!;
    expect(find.text('1/3'), findsOneWidget);

    final animation = controller.animateToPage(
      2,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    await tester.pumpAndSettle();
    await animation;

    expect(find.text('3/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile app bar keeps settings and uses the light design',
      (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: const [],
      navigatorObserver: observer,
    );

    expect(find.byTooltip('Impostazioni'), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.surface);
    expect(appBar.foregroundColor, AppColors.textPrimary);
    await tester.tap(find.byTooltip('Impostazioni'));
    expect(observer.pushes, 1);
  });

  testWidgets('shared background remains visible in list and grid',
      (tester) async {
    await _pumpLoadedHome(tester, rows: const []);

    expect(find.byType(ValtellinaBackground), findsOneWidget);
    expect(find.byKey(const ValueKey('valtellina-background-art')),
        findsOneWidget);
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, isNull);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ValtellinaBackground), findsOneWidget);
    expect(AppColors.background, const Color(0xFFEAF2FB));
  });

  testWidgets('logout remains directly accessible', (tester) async {
    var loggedOut = false;
    await _pumpLoadedHome(
      tester,
      rows: const [],
      onLogout: () => loggedOut = true,
    );

    await tester.scrollUntilVisible(find.text('Logout'), 300);
    await tester.tap(find.text('Logout'));
    expect(loggedOut, isTrue);
  });

  testWidgets('list is default and menu switches both ways', (tester) async {
    await _pumpLoadedHome(tester, rows: const []);

    expect(find.text('Consulta eventi e disponibilità'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Consulta eventi e disponibilità'), findsNothing);
    expect(await AppPreferencesService.loadHomeMenuGridEnabled(), isTrue);

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Consulta eventi e disponibilità'), findsOneWidget);
    expect(await AppPreferencesService.loadHomeMenuGridEnabled(), isFalse);
  });

  testWidgets('grid preference is restored after rebuilding the app',
      (tester) async {
    SharedPreferences.setMockInitialValues({'home_menu_grid_enabled': true});
    await _pumpLoadedHome(tester, rows: const []);

    expect(find.text('Consulta eventi e disponibilità'), findsNothing);
    expect(find.text('Calendario gare'), findsOneWidget);
  });

  testWidgets('notification badge is visible in list and grid', (tester) async {
    await _pumpLoadedHome(tester, rows: const [], unread: 4);

    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('menu navigation works from list', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: const [],
      navigatorObserver: observer,
    );

    await tester.tap(find.text('Calendario gare'));
    expect(observer.pushes, 1);
  });

  testWidgets('menu navigation works from grid', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: const [],
      navigatorObserver: observer,
    );

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendario gare'));
    expect(observer.pushes, 1);
  });

  testWidgets('Race Control exposes loading and error states', (tester) async {
    final completer = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(_home(notion: _PendingNotionService(completer)));
    await tester.pump();
    expect(find.text('Caricamento delle prossime attività…'), findsOneWidget);

    completer.complete(const []);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(_home(notion: _FailingNotionService()));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Impossibile caricare le prossime attività.'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
  });

  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0]) {
    testWidgets('home fits ${width.toInt()} px with 140% text', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _home(
          textScale: 1.4,
          notion: _FakeNotionService([
            _racePage(
              id: 'responsive',
              title: 'Designazione con un titolo volutamente molto lungo',
              date: '2026-11-12',
            ),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Menu principale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0]) {
    testWidgets('grid fits ${width.toInt()} px with 140% text', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'home_menu_grid_enabled': true});

      await tester.pumpWidget(
        _home(
          textScale: 1.4,
          notion: _FakeNotionService([
            _racePage(
              id: 'responsive-grid',
              title: 'Designazione con un titolo volutamente molto lungo',
              date: '2026-11-12',
            ),
          ]),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Centro di controllo Admin'), findsNothing);
      expect(find.text('Calendario gare'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop keeps the sidebar at 1024 px', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLoadedHome(tester, rows: const [], textScale: 1.4);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(ValtellinaBackground), findsOneWidget);
    expect(find.byTooltip('Impostazioni'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Le tue prossime attività'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
