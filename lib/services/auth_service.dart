import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

import '../config/app_environment.dart';
import '../state/session_state.dart';

class AuthService {
  AuthService({PasskeyAuthenticator? passkeyAuthenticator})
      : _passkeyAuthenticator =
            passkeyAuthenticator ?? PasskeyAuthenticator(debugMode: false);

  final PasskeyAuthenticator _passkeyAuthenticator;

  Future<Map<String, dynamic>> loginWithFirebase(
    String email,
    String password,
  ) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final idToken = await credential.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Accesso Firebase non completato.');
    }
    final decoded = await _post({
      'action': 'firebaseLogin',
      'idToken': idToken,
    });
    return _readAuthenticatedUser(decoded);
  }

  Future<void> startFirstAccess(String username, String email) async {
    final decoded = await _post({
      'action': 'startFirstAccess',
      'username': username.trim(),
      'email': email.trim(),
    });
    if (decoded['canSendEmail'] == true) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  // LOGIN: restituisce la pagina dell'utente se username + password sono corretti
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final body = {
      "action": "login",
      "username": username,
      "password": password,
    };

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;

      final rawUser = decoded["user"];
      final sessionToken = decoded["sessionToken"];
      if (rawUser is! Map || sessionToken is! String || sessionToken.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(rawUser)
        ..['_sessionToken'] = sessionToken;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> loginWithPasskey() async {
    final start = await _post({'action': 'passkeyAuthenticationOptions'});
    final options = start['options'];
    final challengeToken = start['challengeToken'];
    if (options is! Map || challengeToken is! String) {
      throw const FormatException('Risposta passkey non valida.');
    }

    final request = AuthenticateRequestType.fromJsonString(jsonEncode(options));
    final authenticatorResponse =
        await _passkeyAuthenticator.authenticate(request);
    final finish = await _post({
      'action': 'passkeyAuthenticationVerify',
      'challengeToken': challengeToken,
      'response': jsonDecode(authenticatorResponse.toJsonString()),
    });
    return _readAuthenticatedUser(finish);
  }

  Future<void> registerPasskey() async {
    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Sessione scaduta: effettua nuovamente il login.');
    }
    final start = await _post(
      {'action': 'passkeyRegistrationOptions'},
      sessionToken: sessionToken,
    );
    final options = start['options'];
    final challengeToken = start['challengeToken'];
    if (options is! Map || challengeToken is! String) {
      throw const FormatException('Risposta passkey non valida.');
    }

    final request = RegisterRequestType.fromJsonString(jsonEncode(options));
    final authenticatorResponse = await _passkeyAuthenticator.register(request);
    await _post(
      {
        'action': 'passkeyRegistrationVerify',
        'challengeToken': challengeToken,
        'response': jsonDecode(authenticatorResponse.toJsonString()),
      },
      sessionToken: sessionToken,
    );
  }

  Future<bool> passkeysEnabled() async {
    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Sessione scaduta: effettua nuovamente il login.');
    }
    final result = await _post(
      {'action': 'passkeyStatus'},
      sessionToken: sessionToken,
    );
    return result['enabled'] == true;
  }

  Future<void> disablePasskeys() async {
    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Sessione scaduta: effettua nuovamente il login.');
    }
    await _post(
      {'action': 'disablePasskeys'},
      sessionToken: sessionToken,
    );
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> payload, {
    String? sessionToken,
  }) async {
    final res = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
      },
      body: jsonEncode(payload),
    );
    if (sessionToken != null) {
      await throwIfSessionExpiredResponse(res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200 || decoded is! Map) {
      final message = decoded is Map ? decoded['error'] : null;
      throw Exception(message ?? 'Servizio di autenticazione non disponibile.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _readAuthenticatedUser(Map<String, dynamic> decoded) {
    final rawUser = decoded['user'];
    final sessionToken = decoded['sessionToken'];
    if (rawUser is! Map || sessionToken is! String || sessionToken.isEmpty) {
      throw const FormatException('Profilo utente non valido.');
    }
    return Map<String, dynamic>.from(rawUser)..['_sessionToken'] = sessionToken;
  }
}
