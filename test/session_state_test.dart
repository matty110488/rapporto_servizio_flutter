import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/state/session_state.dart';

String _sessionTokenWithExpiry(DateTime expiry) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-1',
            'exp': expiry.millisecondsSinceEpoch ~/ 1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$payload.signature';
}

void main() {
  tearDown(() {
    globalLoggedUserId = null;
    globalSessionToken = null;
    globalSessionExpiredHandler = null;
  });

  test('riconosce una sessione scaduta', () {
    final now = DateTime.utc(2026, 7, 31, 12);

    expect(
      isSessionTokenExpired(
        _sessionTokenWithExpiry(now.subtract(const Duration(seconds: 1))),
        now: now,
      ),
      isTrue,
    );
    expect(
      isSessionTokenExpired(
        _sessionTokenWithExpiry(now.add(const Duration(seconds: 1))),
        now: now,
      ),
      isFalse,
    );
    expect(isSessionTokenExpired('token-non-valido', now: now), isTrue);
  });

  test('una risposta 401 chiude la sessione e richiama il gestore', () async {
    var calls = 0;
    globalLoggedUserId = 'user-1';
    globalSessionToken = 'session-token';
    globalSessionExpiredHandler = () async {
      calls++;
    };

    await expectLater(
      throwIfSessionExpiredResponse(401),
      throwsA(isA<SessionExpiredException>()),
    );

    expect(globalLoggedUserId, isNull);
    expect(globalSessionToken, isNull);
    expect(calls, 1);

    await expectLater(
      throwIfSessionExpiredResponse(401),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(calls, 1);
  });

  test('una risposta diversa da 401 lascia attiva la sessione', () async {
    globalLoggedUserId = 'user-1';
    globalSessionToken = 'session-token';

    await throwIfSessionExpiredResponse(500);

    expect(globalLoggedUserId, 'user-1');
    expect(globalSessionToken, 'session-token');
  });
}
