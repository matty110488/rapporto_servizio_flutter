import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
