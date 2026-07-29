import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapporto_servizio/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppThemeController.style.value = AppVisualStyle.light;
  });

  tearDown(() {
    AppThemeController.style.value = AppVisualStyle.light;
  });

  test('salva e ripristina il tema scelto', () async {
    await AppThemeController.setStyle(AppVisualStyle.vintage80);
    AppThemeController.style.value = AppVisualStyle.light;

    await AppThemeController.load();

    expect(AppThemeController.style.value, AppVisualStyle.vintage80);
  });

  test('i temi scuro e retro espongono palette coerenti', () {
    final dark = AppTheme.build(AppVisualStyle.dark);
    final eighties = AppTheme.build(AppVisualStyle.vintage80);
    final nineties = AppTheme.build(AppVisualStyle.vintage90);

    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, isNot(Colors.white));
    expect(eighties.brightness, Brightness.dark);
    expect(eighties.colorScheme.primary, const Color(0xFF39FF14));
    expect(eighties.extension<AppThemeTokens>()!.isRetro, isTrue);
    expect(nineties.brightness, Brightness.light);
    expect(nineties.extension<AppThemeTokens>()!.isRetro, isTrue);
    expect(
      nineties.colorScheme.surface,
      isNot(AppTheme.build(AppVisualStyle.light).colorScheme.surface),
    );
  });
}
