import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  static const _biometricLoginEnabledKey = 'biometric_login_enabled';
  static const _homeMenuGridEnabledKey = 'home_menu_grid_enabled';

  static Future<bool> loadBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricLoginEnabledKey) ?? true;
  }

  static Future<void> saveBiometricLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricLoginEnabledKey, enabled);
  }

  static Future<bool> loadHomeMenuGridEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeMenuGridEnabledKey) ?? false;
  }

  static Future<void> saveHomeMenuGridEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeMenuGridEnabledKey, enabled);
  }
}
