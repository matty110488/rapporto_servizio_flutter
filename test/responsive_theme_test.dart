import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapporto_servizio/pages/login_page.dart';
import 'package:rapporto_servizio/theme/app_theme.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [360.0, 390.0, 768.0, 1440.0]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'login fits at ${width.toInt()} px in ${mode.name} mode',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: const TextScaler.linear(1.35),
                    viewInsets: width <= 390
                        ? const EdgeInsets.only(bottom: 280)
                        : EdgeInsets.zero,
                  ),
                  child: child!,
                );
              },
              home: LoginPage(onLogin: (_) {}),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Accedi a Crono Valtellinesi'), findsOneWidget);
          expect(find.text('Accedi'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
