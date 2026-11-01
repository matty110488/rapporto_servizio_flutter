import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/write_test_web_metadata.dart';

void main() {
  test('installed iOS web app uses an opaque status bar and page surface', () {
    final index = File('web/index.html').readAsStringSync();

    expect(
      index,
      contains(
        'name="apple-mobile-web-app-status-bar-style" content="default"',
      ),
    );
    expect(index, isNot(contains('black-translucent')));
    expect(index, contains('background-color: #ffffff'));
  });

  test('web index loads the local passkey bridge before Flutter', () {
    final index = File('web/index.html').readAsStringSync();
    final bundle = File('web/passkeys_bundle.js');

    expect(index, contains('src="passkeys_bundle.js"'));
    expect(index, contains('src="app_update.js"'));
    expect(
      index.indexOf('passkeys_bundle.js'),
      lessThan(index.indexOf('flutter_bootstrap.js')),
    );
    expect(bundle.existsSync(), isTrue);
    expect(bundle.lengthSync(), greaterThan(1000));
    expect(bundle.readAsStringSync(), contains('PasskeyAuthenticator'));
  });

  test('web update preserves notification worker and local app data', () {
    final script = File('web/app_update.js').readAsStringSync();

    expect(script, contains('flutter_service_worker.js'));
    expect(script, contains("name.startsWith('flutter-')"));
    expect(script, isNot(contains('firebase-messaging-sw.js')));
    expect(script, isNot(contains('localStorage.clear')));
    expect(script, isNot(contains('indexedDB.deleteDatabase')));
    expect(
      File('web/index.html').readAsStringSync().indexOf('app_update.js'),
      lessThan(
        File('web/index.html').readAsStringSync().indexOf(
              'flutter_bootstrap.js',
            ),
      ),
    );
  });

  test('web update manifest matches the compiled app version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionMatch =
        RegExp(r'^version:\s*([^+]+)\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    final manifest = jsonDecode(
      File('web/version.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(versionMatch, isNotNull);
    expect(manifest['version'], versionMatch!.group(1));
    expect(manifest['build_number'], versionMatch.group(2));
  });

  test('TEST deployment metadata uses one numeric build identity', () {
    final metadata = buildTestVersionMetadata(
      version: '2.3.4',
      buildNumber: '123456789',
      gitSha: 'abc123def456',
    );

    expect(metadata, {
      'version': '2.3.4',
      'build_number': '123456789',
      'git_sha': 'abc123def456',
    });
    expect(
      cacheBustFlutterBootstrap(
        '<script src="flutter_bootstrap.js?v=old" async></script>',
        metadata['build_number']!,
      ),
      contains('flutter_bootstrap.js?v=123456789'),
    );
  });

  test('TEST CI build numbers are ordered and reruns stay distinct', () {
    final firstAttempt = calculateTestBuildNumber(
      runId: 123456,
      runAttempt: 1,
    );
    final rerun = calculateTestBuildNumber(
      runId: 123456,
      runAttempt: 2,
    );
    final nextRun = calculateTestBuildNumber(
      runId: 123457,
      runAttempt: 1,
    );

    expect(firstAttempt, greaterThan(29));
    expect(rerun, greaterThan(firstAttempt));
    expect(nextRun, greaterThan(rerun));
  });

  test('TEST workflow passes the generated identity through the web build', () {
    final workflow = File(
      '.github/workflows/deploy-test.yml',
    ).readAsStringSync();

    expect(workflow, contains('--build-name=\$APP_NAME'));
    expect(workflow, contains('--build-number=\$TEST_BUILD_NUMBER'));
    expect(workflow, contains('--dart-define=APP_VERSION=\$APP_VERSION'));
    expect(workflow, contains('write_test_web_metadata.dart'));
    expect(workflow, contains('cp firebase.test.json firebase.json'));
  });

  test('TEST Firebase config revalidates only mutable app shell files', () {
    final config = jsonDecode(
      File('firebase.test.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final headers = hosting['headers'] as List<dynamic>;
    final cacheRules = <String, String>{};
    for (final entry in headers.cast<Map<String, dynamic>>()) {
      final values = entry['headers'] as List<dynamic>;
      final cacheHeader = values.cast<Map<String, dynamic>>().firstWhere(
            (header) => header['key'] == 'Cache-Control',
          );
      cacheRules[entry['source'] as String] = cacheHeader['value'] as String;
    }

    for (final path in [
      '/index.html',
      '/version.json',
      '/flutter_bootstrap.js',
      '/main.dart.js',
      '/flutter.js',
      '/manifest.json',
    ]) {
      expect(cacheRules[path], contains('no-cache'));
    }
    expect(cacheRules.keys, isNot(contains('**')));
    expect(cacheRules.keys, isNot(contains('/assets/**')));
  });
}
