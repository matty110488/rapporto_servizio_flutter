import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/config/app_environment.dart';

void main() {
  test('una build normale usa configurazione e backend di produzione', () {
    expect(appEnvironment, 'prod');
    expect(isTestEnvironment, isFalse);
    expect(appDisplayName, 'Crono Valtellinesi');
    expect(
      apiUrl,
      'https://rapporto-servizio-flutter.vercel.app/api/notion-query',
    );
  });
}
