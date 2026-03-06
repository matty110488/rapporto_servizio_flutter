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
    final url = kIsWeb
        ? "https://rapporto-servizio-flutter.vercel.app/api/notion-query"
        : "https://api.notion.com/v1/databases/$cronometristiDbId/query";

    final body = {
      "filter": {
        "and": [
          {
            "property": "USERNAME",
            "rich_text": {"equals": username}
          },
          {
            "property": "PASSWORD",
            "rich_text": {"equals": password}
          }
        ]
      }
    };

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
      print("❌ Errore Notion login: ${res.body}");
      return null;
    }

    final data = jsonDecode(res.body);

    if (data["results"].isEmpty) {
      return null; // username o password errati
    }

    return data["results"][0]; // pagina utente
  }
}
