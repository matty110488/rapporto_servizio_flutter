import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_config.dart';
import 'package:rapporto_servizio/pages/home_page.dart';
import 'package:rapporto_servizio/services/notion_service.dart';
import 'package:rapporto_servizio/services/push_notification_service.dart';
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
  List<PushNotice>? notifications,
  double textScale = 1,
  bool disableAnimations = false,
  List<HomeWelcomePhoto>? welcomePhotos,
  Duration welcomePhotoInterval = const Duration(seconds: 7),
  Duration welcomePhotoFadeDuration = const Duration(milliseconds: 800),
  NavigatorObserver? navigatorObserver,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
    builder: (context, child) => ValtellinaBackground(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
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
      initialNotifications: notifications,
      welcomePhotos: welcomePhotos ??
          const [
            HomeWelcomePhoto(
              assetName: 'assets/home-valtellina-header.webp',
              alignment: Alignment.centerLeft,
            ),
            HomeWelcomePhoto(assetName: 'assets/sci-piste.webp'),
            HomeWelcomePhoto(assetName: 'assets/panorama-inverno.webp'),
            HomeWelcomePhoto(
              assetName: 'assets/gara-sci.webp',
              alignment: Alignment(0, -0.35),
            ),
          ],
      welcomePhotoInterval: welcomePhotoInterval,
      welcomePhotoFadeDuration: welcomePhotoFadeDuration,
    ),
  );
}

Future<void> _pumpLoadedHome(
  WidgetTester tester, {
  required List<Map<String, dynamic>> rows,
  VoidCallback? onLogout,
  int unread = 0,
  List<PushNotice>? notifications,
  double textScale = 1,
  bool disableAnimations = false,
  List<HomeWelcomePhoto>? welcomePhotos,
  Duration welcomePhotoInterval = const Duration(seconds: 7),
  Duration welcomePhotoFadeDuration = const Duration(milliseconds: 800),
  NavigatorObserver? navigatorObserver,
}) async {
  await tester.pumpWidget(
    _home(
      notion: _FakeNotionService(rows),
      onLogout: onLogout,
      unread: unread,
      notifications: notifications,
      textScale: textScale,
      disableAnimations: disableAnimations,
      welcomePhotos: welcomePhotos,
      welcomePhotoInterval: welcomePhotoInterval,
      welcomePhotoFadeDuration: welcomePhotoFadeDuration,
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

  testWidgets('Home 3.0 exposes the Valtellina experience without a menu',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
    );

    expect(find.byType(ValtellinaBackground), findsOneWidget);
    expect(
      find.byKey(const ValueKey('valtellina-background-art')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-alpine-panorama')),
      findsOneWidget,
    );
    final welcomePhoto = tester.widget<Image>(
      find.byKey(const ValueKey('home-welcome-photo-0')),
    );
    expect(
      (welcomePhoto.image as AssetImage).assetName,
      'assets/home-valtellina-header.webp',
    );
    expect(welcomePhoto.fit, BoxFit.cover);
    expect(welcomePhoto.alignment, Alignment.centerLeft);
    expect(
      find.byKey(const ValueKey('home-photo-swipe-area')),
      findsOneWidget,
    );
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(ValueKey('home-photo-indicator-$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('home-welcome-photo-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-identity-banner')),
      findsOneWidget,
    );
    expect(find.text('PRECISIONE · SERVIZIO · PASSIONE'), findsOneWidget);
    expect(find.text('Menu principale'), findsNothing);
    expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      isNull,
    );
    expect(AppColors.background, const Color(0xFFEAF2FB));
  });

  testWidgets('welcome photos rotate with an 800 ms fade and wrap around',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      welcomePhotoInterval: const Duration(seconds: 2),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.descendant(
        of: find.byKey(const ValueKey('home-photo-carousel')),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    expect(switcher.duration, const Duration(milliseconds: 800));
    expect(
      find.byKey(const ValueKey('home-welcome-photo-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.byType(FadeTransition), findsWidgets);
    expect(
      find.byKey(const ValueKey('home-welcome-photo-1')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 800));

    for (var index = 2; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.byKey(ValueKey('home-welcome-photo-$index')),
        findsOneWidget,
      );
    }

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.byKey(const ValueKey('home-welcome-photo-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome carousel supports horizontal swiping and indicators',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      welcomePhotoInterval: const Duration(hours: 1),
    );

    final firstIndicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('home-photo-indicator-0')),
    );
    expect(firstIndicator.constraints?.maxWidth, 15);

    await tester.fling(
      find.byKey(const ValueKey('home-photo-swipe-area')),
      const Offset(-600, 0),
      1200,
    );
    await tester.pumpAndSettle();

    final secondPhoto = tester.widget<Image>(
      find.byKey(const ValueKey('home-welcome-photo-1')),
    );
    expect(
        (secondPhoto.image as AssetImage).assetName, 'assets/sci-piste.webp');
    final secondIndicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('home-photo-indicator-1')),
    );
    expect(secondIndicator.constraints?.maxWidth, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('greeting stays fixed while welcome photos change',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      welcomePhotoInterval: const Duration(seconds: 1),
    );

    final greeting = find.textContaining('Mattia');
    expect(greeting, findsOneWidget);
    expect(
      find.ancestor(of: greeting, matching: find.byType(AnimatedSwitcher)),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 800));
    expect(greeting, findsOneWidget);
    expect(
      find.ancestor(of: greeting, matching: find.byType(AnimatedSwitcher)),
      findsNothing,
    );
  });

  testWidgets('one welcome photo has no swipe layer or indicators',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      welcomePhotos: const [
        HomeWelcomePhoto(
          assetName: 'assets/home-valtellina-header.webp',
        ),
      ],
      welcomePhotoInterval: const Duration(milliseconds: 100),
    );

    expect(
      find.byKey(const ValueKey('home-welcome-photo-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-photo-swipe-area')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-photo-indicator-0')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('home-welcome-photo-0')),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion disables automatic welcome photo rotation',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      disableAnimations: true,
      welcomePhotoInterval: const Duration(milliseconds: 100),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.descendant(
        of: find.byKey(const ValueKey('home-photo-carousel')),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    expect(switcher.duration, Duration.zero);
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('home-welcome-photo-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-welcome-photo-1')),
      findsNothing,
    );
  });

  testWidgets('welcome carousel disposes timer and controller safely',
      (tester) async {
    await _pumpLoadedHome(
      tester,
      rows: const [],
      notifications: const [],
      welcomePhotoInterval: const Duration(milliseconds: 100),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification preview uses real data and opens notifications',
      (tester) async {
    final observer = _RecordingNavigatorObserver();
    await _pumpLoadedHome(
      tester,
      rows: const [],
      navigatorObserver: observer,
      notifications: [
        PushNotice(
          title: 'Convocazione riunione',
          body: 'La riunione tecnica è fissata per venerdì sera.',
          read: false,
          receivedAt: DateTime(2026, 10, 30),
        ),
      ],
    );

    final notificationPreview =
        find.byKey(const ValueKey('home-notification-preview'));
    await tester.scrollUntilVisible(
      notificationPreview,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Convocazione riunione'), findsOneWidget);
    expect(
      find.text('La riunione tecnica è fissata per venerdì sera.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('home-notification-preview')),
    );
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

      expect(
        find.byKey(const ValueKey('home-alpine-panorama')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-identity-banner')),
        findsOneWidget,
      );
      expect(find.text('Menu principale'), findsNothing);
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
