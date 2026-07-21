import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/utils/notion_user.dart';

void main() {
  test('username wins over technical passkey data', () {
    final user = <String, dynamic>{
      'properties': <String, dynamic>{
        'PASSKEYS': {
          'type': 'rich_text',
          'rich_text': [
            {'plain_text': '[{"id":"technical-token"}]'},
          ],
        },
        'USERNAME': {
          'type': 'rich_text',
          'rich_text': [
            {'plain_text': 'Mario Rossi'},
          ],
        },
      },
    };

    expect(extractNotionUserName(user), 'Mario Rossi');
  });

  test('recognizes admin profiles from supported Notion fields', () {
    expect(
      isNotionAdmin({
        'properties': {
          'ADMIN': {'checkbox': true},
        },
      }),
      isTrue,
    );
    expect(
      isNotionAdmin({
        'properties': {
          'RUOLO': {
            'select': {'name': 'Amministratore'},
          },
        },
      }),
      isTrue,
    );
    expect(
      isNotionAdmin({
        'properties': {
          'RUOLO': {
            'select': {'name': 'Cronometrista'},
          },
        },
      }),
      isFalse,
    );
  });
}
