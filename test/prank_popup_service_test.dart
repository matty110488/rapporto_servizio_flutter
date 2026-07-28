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

    expect(
      find.text('Tempo ufficiale: sempre troppo presto'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('Tempo ufficiale: sempre troppo presto'),
      findsNothing,
    );
  });
}
