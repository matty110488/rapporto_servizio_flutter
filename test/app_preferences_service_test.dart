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
}
