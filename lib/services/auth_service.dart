import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String apiKey;
  final String cronometristiDbId;

  AuthService({
    required this.apiKey,
    required this.cronometristiDbId,
  });

  // LOGIN: restituisce la pagina dell'utente se username + password sono corretti
  Future<Map<String, dynamic>?> login(String username, String password) async {
    const usernameProperty = "Username";
    const passwordProperty = "Password";

    final url = kIsWeb
        ? "https://rapporto-servizio-flutter.vercel.app/api/notion-query"
        : "https://api.notion.com/v1/databases/$cronometristiDbId/query";

    final body = {
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
        Uri.parse(url),
        headers: kIsWeb
            ? {
                "Content-Type": "application/json",
              }
            : {
                "Authorization": "Bearer $apiKey",
                "Notion-Version": "2022-06-28",
                "Content-Type": "application/json",
              },
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        print("Login Notion error (${res.statusCode}): ${res.body}");
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
    } catch (e) {
      print("Login parsing/network error: $e");
      return null;
    }
  }
}
