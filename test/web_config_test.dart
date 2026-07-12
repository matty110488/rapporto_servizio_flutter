import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web index loads the local passkey bridge before Flutter', () {
    final index = File('web/index.html').readAsStringSync();
    final bundle = File('web/passkeys_bundle.js');

    expect(index, contains('src="passkeys_bundle.js"'));
    expect(
      index.indexOf('passkeys_bundle.js'),
      lessThan(index.indexOf('flutter_bootstrap.js')),
    );
    expect(bundle.existsSync(), isTrue);
    expect(bundle.lengthSync(), greaterThan(1000));
    expect(bundle.readAsStringSync(), contains('PasskeyAuthenticator'));
  });
}
