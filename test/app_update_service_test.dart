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
}
