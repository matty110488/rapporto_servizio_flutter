import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/services/prank_popup_service.dart';

void main() {
  testWidgets('legendary mode shows an explicit easter egg dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => PrankPopupService.showLegendaryMode(context),
            child: const Text('Apri'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Modalità cronometrista leggendario'), findsOneWidget);
    expect(find.text('Tempo preso!'), findsOneWidget);

    await tester.tap(find.text('Tempo preso!'));
    await tester.pumpAndSettle();
    expect(find.text('Modalità cronometrista leggendario'), findsNothing);
  });

  testWidgets('checkered flag overlay closes automatically', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => PrankPopupService.showCheckeredFlag(context),
            child: const Text('Bandiera'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bandiera'));
    await tester.pump();

    expect(find.byIcon(Icons.sports_score), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.sports_score), findsNothing);
  });
}
