import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/widgets/standard_app_bar_actions.dart';

void main() {
  testWidgets('standard app bar exposes help, refresh and home',
      (tester) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Schermata'),
              actions: standardAppBarActions(
                context,
                helpTitle: 'Aiuto schermata',
                helpContent: const ['Istruzione utile'],
                onRefresh: () => refreshCount++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Aiuto'), findsOneWidget);
    expect(find.byTooltip('Aggiorna'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Aggiorna'));
    await tester.pump();
    expect(refreshCount, 1);

    await tester.tap(find.byTooltip('Aiuto'));
    await tester.pumpAndSettle();
    expect(find.text('Aiuto schermata'), findsOneWidget);
    expect(find.text('Istruzione utile'), findsOneWidget);
  });
}
