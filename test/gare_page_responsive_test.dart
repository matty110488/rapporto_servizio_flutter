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

  for (final width in [320.0, 375.0, 393.0, 430.0, 768.0]) {
    testWidgets('calendar fits ${width.toInt()} px at 140% text',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_calendar(textScale: 1.4));
      await tester.pump();

      expect(find.text('Calendario gare'), findsOneWidget);
      expect(find.byType(ValtellinaBackground), findsOneWidget);
      expect(find.text('Sport'), findsOneWidget);
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

  testWidgets('filter hint supports scrolling and selected sport',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_calendar(textScale: 1));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsOneWidget,
    );
    final filterScroll = find.descendant(
      of: find.byType(AppHorizontalScrollHint),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(filterScroll, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsNothing,
    );

    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hockey su ghiaccio').last);
    await tester.pumpAndSettle();
    final sportDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byType(AppHorizontalScrollHint),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(sportDropdown.value, 'Hockey su ghiaccio');
    expect(
      find.byKey(const ValueKey('horizontal-scroll-hint')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
