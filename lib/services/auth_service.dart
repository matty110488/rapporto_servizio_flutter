import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  static const _webProxyUrl =
      'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
  AuthService();

  // LOGIN: restituisce la pagina dell'utente se username + password sono corretti
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final body = {
      "action": "login",
      "username": username,
      "password": password,
    };

    try {
      final res = await http.post(
        Uri.parse(_webProxyUrl),
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
}
