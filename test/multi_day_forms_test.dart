import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/widgets/cronometristi_form.dart';
import 'package:rapporto_servizio/widgets/gara_form.dart';

void main() {
  testWidgets('gara form keeps only the actual package dates', (tester) async {
    final key = GlobalKey<GaraFormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GaraForm(key: key)),
        ),
      ),
    );

    key.currentState!.applyPackageData(
      nome: 'Meeting Alpino',
      organizzatore: 'Associazione',
      sportValue: 'Nuoto',
      luogo: 'Sondrio',
      dates: [DateTime(2026, 8, 12), DateTime(2026, 8, 14)],
    );
    await tester.pump();

    expect(
      key.currentState!.getOrariGiornata().keys,
      ['2026-08-12', '2026-08-14'],
    );
  });

  testWidgets('time selector uses five-minute intervals', (tester) async {
    final key = GlobalKey<GaraFormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GaraForm(key: key)),
        ),
      ),
    );

    key.currentState!.applyPackageData(
      nome: 'Meeting Alpino',
      organizzatore: 'Associazione',
      sportValue: 'Nuoto',
      luogo: 'Sondrio',
      dates: [DateTime(2026, 8, 12)],
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('time-selector-oraDa-2026-08-12')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Scegli ora e minuti a intervalli di 5 minuti.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('minute-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-time-selection')),
    );
    await tester.pumpAndSettle();

    expect(
      key.currentState!.getOrariGiornata()['2026-08-12']?['oraDa'],
      '08:30',
    );

    await tester.tap(
      find.byKey(const ValueKey('break-switch-2026-08-12')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Scegli la durata a intervalli di 5 minuti.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-time-selection')),
    );
    await tester.pumpAndSettle();

    final schedule = key.currentState!.getOrariGiornata()['2026-08-12']!;
    expect(schedule['pausa'], 'true');
    expect(schedule['pausaOre'], '0');
    expect(schedule['pausaMinuti'], '30');
  });

  testWidgets('each timekeeper receives only their assigned dates',
      (tester) async {
    final key = GlobalKey<CronometristiFormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CronometristiForm(key: key)),
        ),
      ),
    );

    key.currentState!.syncDaysWithDates([
      DateTime(2026, 8, 12),
      DateTime(2026, 8, 14),
    ]);
    key.currentState!.setCronometristiPerDate({
      'Mario Rossi': [DateTime(2026, 8, 12)],
      'Luigi Bianchi': [DateTime(2026, 8, 14)],
    });
    await tester.pump();

    final rows = key.currentState!.getData();
    final datesByName = <String, List<String>>{
      for (final row in rows)
        row['nome'] as String: (row['giorni'] as List)
            .map((day) => (day as Map)['data'] as String)
            .toList(),
    };
    expect(datesByName['Mario Rossi'], ['2026-08-12']);
    expect(datesByName['Luigi Bianchi'], ['2026-08-14']);

    key.currentState!.rimuoviRiga(1);
    expect(key.currentState!.getData(), hasLength(1));

    key.currentState!.setCronometristiPerDate({
      'Mario Rossi': [DateTime(2026, 8, 12)],
      'Luigi Bianchi': [DateTime(2026, 8, 14)],
    });
    await tester.pump();

    expect(
      key.currentState!.getData().map((row) => row['nome']),
      containsAll(['Mario Rossi', 'Luigi Bianchi']),
    );
  });

  testWidgets('worked hours are calculated from schedule and daily break',
      (tester) async {
    final key = GlobalKey<CronometristiFormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CronometristiForm(key: key)),
        ),
      ),
    );

    key.currentState!.syncDaysWithDates([DateTime(2026, 8, 12)]);
    key.currentState!.setCronometristiPerDate({
      'Mario Rossi': [DateTime(2026, 8, 12)],
    });
    key.currentState!.setOrari({
      '2026-08-12': {
        'oraDa': '08:00',
        'oraA': '17:30',
        'pausa': 'true',
        'pausaOre': '1',
        'pausaMinuti': '30',
      },
    });
    await tester.pump();

    var giorno = (key.currentState!.getData().single['giorni'] as List).single
        as Map<String, dynamic>;
    expect(giorno['ore'], '8');

    final oreField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Ore',
    );
    await tester.enterText(oreField, '7.5');
    await tester.pump();

    giorno = (key.currentState!.getData().single['giorni'] as List).single
        as Map<String, dynamic>;
    expect(giorno['ore'], '7.5');

    key.currentState!.setOrari({
      '2026-08-12': {
        'oraDa': '08:00',
        'oraA': '17:30',
        'pausa': 'true',
        'pausaOre': '1',
        'pausaMinuti': '30',
      },
    });
    expect(giorno['ore'], '7.5');
  });
}
