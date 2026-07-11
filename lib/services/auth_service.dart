import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthService {
  static const _webProxyUrl =
      'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
  final String cronometristiDbId;

  AuthService({required this.cronometristiDbId});

  // LOGIN: restituisce la pagina dell'utente se username + password sono corretti
  Future<Map<String, dynamic>?> login(String username, String password) async {
    const usernameProperty = "USERNAME";
    const passwordProperty = "PASSWORD";

    final body = {
      "action": "queryDatabase",
      "databaseId": cronometristiDbId,
      "filter": {
        "and": [
          {
            "property": usernameProperty,
            "rich_text": {"equals": username}
          },
          {
            "property": passwordProperty,
            "rich_text": {"equals": password}
          }
        ]
      }
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

      final results = decoded["results"];
      if (results is! List || results.isEmpty) {
        return null; // username o password errati
      }

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;
      return first; // pagina utente
    } catch (_) {
      return null;
    }
  }
}
