import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/models/gara.dart';
import 'package:rapporto_servizio/pages/gare_page.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';
import 'package:rapporto_servizio/widgets/app_ui.dart';

Gara _gara({
  required String id,
  required String title,
  required String date,
  String packageId = '',
}) {
  return Gara(
    id: id,
    titolo: title,
    sport: 'Hockey su ghiaccio',
    dataGara: date,
    dataGaraFine: '',
    localita: 'Una località valtellinese dal nome molto lungo',
    sitoGara: '',
    organizzatore: 'Associazione',
    idSicWin: packageId,
    dataRichiesta: '',
    kronosIds: const [],
    dscIds: const [],
    pcSegreteriaIds: const [],
    apparecchiature: const [],
    tipologia: '',
    status: 'DESIGNAZIONE INVIATA',
  );
}

Widget _calendar({required double textScale}) {
  final gare = [
    _gara(
      id: 'long-title',
      title: 'HC Chiavenna contro Plebiscito Padova nella finale nazionale '
          'con un titolo volutamente molto lungo',
      date: '2026-11-10',
    ),
    _gara(
      id: 'package-one',
      title: 'Trofeo Valtellina - Sabato',
      date: '2026-11-14',
      packageId: 'PK-42',
    ),
    _gara(
      id: 'package-two',
      title: 'Trofeo Valtellina - Domenica',
      date: '2026-11-15',
      packageId: 'PK-42',
    ),
  ];

  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => ValtellinaBackground(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
    home: GarePage(
      loggedUser: const {'id': 'test-user'},
      initialGare: gare,
    ),
  );
}

void main() {
  testWidgets('calendar controls fit 320 px at 140% text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => ValtellinaBackground(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
        ),
        home: const GarePage(
          loggedUser: {'id': 'test-user'},
          initialGare: [],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0, 768.0]) {
    testWidgets('calendar fits ${width.toInt()} px at 140% text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_calendar(textScale: 1.4));
      await tester.pump();

      expect(find.text('Calendario gare'), findsOneWidget);
      expect(find.byType(ValtellinaBackground), findsNWidgets(2));
      expect(
        tester
            .widgetList<ValtellinaBackground>(
              find.byType(ValtellinaBackground),
            )
            .where((background) => background.crispMountains),
        hasLength(1),
      );
      expect(find.text('Sport'), findsOneWidget);
      expect(find.text('Tutte'), findsOneWidget);
      expect(find.text('Disponibilità'), findsOneWidget);
      expect(find.text('Designato'), findsOneWidget);
      expect(find.byType(AppHorizontalScrollHint), findsNothing);

      for (final label in ['Sport', 'Tutte', 'Disponibilità', 'Designato']) {
        final bounds = tester.getRect(find.text(label));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width));
      }

      if (width == 320) {
        expect(
          find.byKey(
            const ValueKey('calendar-general-filters-stacked'),
          ),
          findsOneWidget,
        );
      } else {
        expect(
          find.byKey(
            const ValueKey('calendar-general-filters-inline'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('3 gare prossime'), findsOneWidget);
      expect(find.text('NOVEMBRE 2026'), findsOneWidget);
      expect(find.textContaining('HC Chiavenna'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('month expansion keeps package races and long titles',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_calendar(textScale: 1));
    await tester.pump();

    expect(find.text('Trofeo Valtellina'), findsOneWidget);
    await tester.tap(find.text('NOVEMBRE 2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HC Chiavenna'), findsNothing);

    await tester.tap(find.text('NOVEMBRE 2026'));
    await tester.pumpAndSettle();
    expect(find.textContaining('HC Chiavenna'), findsOneWidget);
    expect(find.text('Trofeo Valtellina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sport filter remains directly accessible without scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_calendar(textScale: 1));
    await tester.pump();

    expect(find.byType(AppHorizontalScrollHint), findsNothing);
    final sportBounds = tester.getRect(find.text('Sport'));
    expect(sportBounds.right, lessThanOrEqualTo(390 - AppSpacing.md));

    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hockey su ghiaccio').last);
    await tester.pumpAndSettle();
    final sportDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-sport-filter')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(sportDropdown.value, 'Hockey su ghiaccio');
    expect(tester.takeException(), isNull);
  });
}
