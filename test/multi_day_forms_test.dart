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
}
