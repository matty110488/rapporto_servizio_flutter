import 'dart:convert';

String? globalLoggedUserId;
String? globalSessionToken;

typedef SessionExpiredHandler = Future<void> Function();

SessionExpiredHandler? globalSessionExpiredHandler;

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => 'Sessione scaduta: effettua nuovamente il login.';
}

bool isSessionTokenExpired(String token, {DateTime? now}) {
  try {
    final parts = token.split('.');
    if (parts.length != 2) return true;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts.first))),
    );
    if (payload is! Map || payload['exp'] is! num) return true;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (payload['exp'] as num).toInt() * 1000,
    );
    return !expiresAt.isAfter(now ?? DateTime.now());
  } catch (_) {
    return true;
  }
}

Future<void> throwIfSessionExpiredResponse(int statusCode) async {
  if (statusCode != 401) return;

  final hadActiveSession =
      globalSessionToken != null || globalLoggedUserId != null;
  globalSessionToken = null;
  globalLoggedUserId = null;

  if (hadActiveSession) {
    await globalSessionExpiredHandler?.call();
  }
  throw const SessionExpiredException();
}
