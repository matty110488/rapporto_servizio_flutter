import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapporto_servizio/services/app_preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses biometric login by default', () async {
    expect(
      await AppPreferencesService.loadBiometricLoginEnabled(),
      isTrue,
    );
  });

  test('persists biometric preference', () async {
    await AppPreferencesService.saveBiometricLoginEnabled(false);
    expect(
      await AppPreferencesService.loadBiometricLoginEnabled(),
      isFalse,
    );
  });

  test('uses the system theme by default', () async {
    expect(await AppPreferencesService.loadThemeMode(), ThemeMode.system);
  });

  test('persists the selected theme', () async {
    await AppPreferencesService.saveThemeMode(ThemeMode.dark);
    expect(await AppPreferencesService.loadThemeMode(), ThemeMode.dark);
  });
}
