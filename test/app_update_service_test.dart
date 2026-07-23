import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/services/app_update_service.dart';

void main() {
  test('detects a published app version newer than the compiled build', () {
    final update = appUpdateFromVersionPayload(
      const {'version': '2.1.0', 'build_number': '21'},
      currentVersion: '2.0.2+20',
    );

    expect(update, isNotNull);
    expect(update!.latestVersion, '2.1.0+21');
    expect(update.latestVersionLabel, '2.1.0 (21)');
  });

  test('does not prompt when published and compiled versions match', () {
    final update = appUpdateFromVersionPayload(
      const {'version': '2.0.2', 'build_number': '20'},
      currentVersion: '2.0.2+20',
    );

    expect(update, isNull);
  });

  test('reads Android APK metadata from the update manifest', () {
    final update = appUpdateFromVersionPayload(
      const {
        'version': '2.1.1',
        'build_number': '22',
        'android': {
          'apk_url': 'https://example.com/crono.apk',
          'sha256': 'ABC123',
        },
      },
      currentVersion: '2.1.0+21',
    );

    expect(update, isNotNull);
    expect(update!.androidApkUrl, 'https://example.com/crono.apk');
    expect(update.androidSha256, 'abc123');
  });

  test('does not offer an older published build', () {
    final update = appUpdateFromVersionPayload(
      const {'version': '2.0.9', 'build_number': '20'},
      currentVersion: '2.1.0+21',
    );

    expect(update, isNull);
  });
}
