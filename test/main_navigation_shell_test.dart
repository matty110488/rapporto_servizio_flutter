import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/pages/gare_page.dart';
import 'package:rapporto_servizio/pages/main_navigation_shell.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';
import 'package:rapporto_servizio/widgets/app_ui.dart';

const _user = {
  'id': 'user-1',
  'properties': {
    'NOME': {
      'rich_text': [
        {'plain_text': 'Mattia'},
      ],
    },
  },
};

const _adminUser = {
  'id': 'admin-1',
  'properties': {
    'ADMIN': {'checkbox': true},
  },
};

Gara _calendarRace() {
  return Gara(
    id: 'race-1',
    titolo: 'Trofeo Valtellina',
    sport: 'Hockey su ghiaccio',
    dataGara: '2026-11-10',
    dataGaraFine: '',
    localita: 'Sondrio',
    sitoGara: '',
    organizzatore: 'Associazione',
    idSicWin: '',
    dataRichiesta: '',
    kronosIds: const [],
    dscIds: const [],
    pcSegreteriaIds: const [],
    apparecchiature: const [],
    tipologia: '',
    status: 'DESIGNAZIONE INVIATA',
  );
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) pushes++;
  }
}

Widget _testApp({
  MainSectionBuilder? sectionBuilder,
  NavigatorObserver? observer,
  Map<String, dynamic> user = _user,
  double textScale = 1,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    navigatorObservers: [if (observer != null) observer],
    builder: (context, child) => ValtellinaBackground(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewPadding: viewPadding,
          padding: viewPadding,
        ),
        child: child!,
      ),
    ),
    home: MainNavigationShell(
      loggedUser: user,
      onLogout: () {},
      sectionBuilder: sectionBuilder ?? _sectionBuilder,
    ),
  );
}

Widget _sectionBuilder(
  MainNavigationSection section,
  ValueChanged<MainNavigationSection> onSelectSection,
) {
  return Scaffold(
    body: Center(
      child: Text(
        'section-${section.name}',
        key: ValueKey('section-${section.name}'),
      ),
    ),
  );
}

void _setSurface(WidgetTester tester, double width, {double height = 800}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _tapDestination(
  WidgetTester tester,
  MainNavigationSection section,
) async {
  await tester.tap(find.byKey(ValueKey('main-navigation-${section.name}')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile navigation exposes and selects all five destinations',
      (tester) async {
    _setSurface(tester, 393);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(_testApp(observer: observer));
    await tester.pumpAndSettle();

    for (final label in const [
      'Home',
      'Calendario',
      'Designazioni',
      'Rapportini',
      'Altro',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    for (final section in MainNavigationSection.values) {
      await _tapDestination(tester, section);
      expect(find.byKey(ValueKey('section-${section.name}')), findsOneWidget);
      final semantics = tester.getSemantics(
        find.byKey(ValueKey('main-navigation-${section.name}')),
      );
      expect(
        semantics.flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
    }

    expect(observer.pushes, 0);
  });

  testWidgets('primary sections are created lazily and only once',
      (tester) async {
    _setSurface(tester, 393);
    final builds = <MainNavigationSection, int>{};

    await tester.pumpWidget(
      _testApp(
        sectionBuilder: (section, onSelectSection) {
          builds.update(section, (value) => value + 1, ifAbsent: () => 1);
          return _sectionBuilder(section, onSelectSection);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(builds, {MainNavigationSection.home: 1});
    await _tapDestination(tester, MainNavigationSection.calendar);
    await _tapDestination(tester, MainNavigationSection.designations);
    await _tapDestination(tester, MainNavigationSection.home);
    await _tapDestination(tester, MainNavigationSection.calendar);

    expect(builds[MainNavigationSection.home], 1);
    expect(builds[MainNavigationSection.calendar], 1);
    expect(builds[MainNavigationSection.designations], 1);
  });

  testWidgets('system back from a primary section returns to Home',
      (tester) async {
    _setSurface(tester, 393);
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await _tapDestination(tester, MainNavigationSection.calendar);
    expect(find.byKey(const ValueKey('section-calendar')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('section-home')), findsOneWidget);
  });

  testWidgets('calendar filter state survives section changes', (tester) async {
    _setSurface(tester, 393, height: 1000);
    await tester.pumpWidget(
      _testApp(
        sectionBuilder: (section, onSelectSection) {
          if (section == MainNavigationSection.calendar) {
            return GarePage(
              loggedUser: _user,
              initialGare: [_calendarRace()],
              onOpenHome: () => onSelectSection(MainNavigationSection.home),
            );
          }
          return _sectionBuilder(section, onSelectSection);
        },
      ),
    );
    await tester.pumpAndSettle();

    await _tapDestination(tester, MainNavigationSection.calendar);
    await tester.tap(find.text('Mia disponibilità'));
    await tester.pumpAndSettle();

    AppFilterChip selectedFilter() => tester.widget<AppFilterChip>(
          find.ancestor(
            of: find.text('Mia disponibilità'),
            matching: find.byType(AppFilterChip),
          ),
        );

    expect(selectedFilter().selected, isTrue);
    await _tapDestination(tester, MainNavigationSection.home);
    await _tapDestination(tester, MainNavigationSection.calendar);
    expect(selectedFilter().selected, isTrue);
  });

  testWidgets('secondary routes hide the bar and return to their section',
      (tester) async {
    _setSurface(tester, 393);
    await tester.pumpWidget(
      _testApp(
        sectionBuilder: (section, onSelectSection) {
          if (section != MainNavigationSection.calendar) {
            return _sectionBuilder(section, onSelectSection);
          }
          return Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Text('Dettaglio gara'),
                      ),
                    ),
                  ),
                  child: const Text('Apri dettaglio'),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await _tapDestination(tester, MainNavigationSection.calendar);
    await tester.tap(find.text('Apri dettaglio'));
    await tester.pumpAndSettle();

    expect(find.text('Dettaglio gara'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-bottom-navigation')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Apri dettaglio'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('main-bottom-navigation')), findsOneWidget);
  });

  testWidgets('bottom navigation respects the lower safe area', (tester) async {
    _setSurface(tester, 393);
    await tester.pumpWidget(
      _testApp(viewPadding: const EdgeInsets.only(bottom: 24)),
    );
    await tester.pumpAndSettle();

    final destinationsBottom = tester
        .getBottomLeft(
            find.byKey(const ValueKey('main-navigation-destinations')))
        .dy;
    expect(destinationsBottom, lessThanOrEqualTo(776));
  });

  testWidgets('desktop uses one sidebar and no bottom navigation',
      (tester) async {
    _setSurface(tester, 1024);
    await tester.pumpWidget(_testApp(textScale: 1.4));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('main-navigation-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-bottom-navigation')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0]) {
    testWidgets('bottom navigation fits ${width.toInt()} px at 140% text',
        (tester) async {
      _setSurface(tester, width);
      await tester.pumpWidget(_testApp(textScale: 1.4));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('main-bottom-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('More exposes Admin only to authorized users', (tester) async {
    _setSurface(tester, 393);
    var loggedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MorePage(
          loggedUser: _adminUser,
          onLogout: () => loggedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centro di controllo Admin'), findsOneWidget);
    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('Notifiche'), findsOneWidget);
    expect(find.text('Impostazioni'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Logout'), 200);
    await tester.tap(find.text('Logout'));
    expect(loggedOut, isTrue);

    await tester.pumpWidget(
      MaterialApp(home: MorePage(loggedUser: _user, onLogout: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centro di controllo Admin'), findsNothing);
  });
}
