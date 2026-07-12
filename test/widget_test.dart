import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapporto_servizio/main.dart';

void main() {
  testWidgets('App without a saved session shows the login page',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CronoValtellinesiApp());
    await tester.pumpAndSettle();

    expect(find.text('Login Cronometristi'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Accedi'), findsOneWidget);
    expect(find.text('Accedi con Face ID o impronta'), findsOneWidget);
  });
}
