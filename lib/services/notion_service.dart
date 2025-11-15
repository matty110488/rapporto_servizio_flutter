import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  final String apiKey;
  final String databaseId;

  NotionService({
    required this.apiKey,
    required this.databaseId,
  });

  // ---------------------------
  // 📌 QUERY DATABASE
  // ---------------------------
  Future<List<Map<String, dynamic>>> fetchGare() async {
    final url = "https://api.notion.com/v1/databases/$databaseId/query";

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28",
      },
    );

    if (res.statusCode != 200) {
      print("STATUS CODE: ${res.statusCode}");
      print("BODY: ${res.body}");
      throw Exception("Errore Notion: ${res.body}");
    }

    final data = jsonDecode(res.body);

    // DEBUG — stampa tutte le proprietà della prima riga
    if (data["results"].isNotEmpty) {
      print("\n=== DEBUG PROPERTIES ===");
      final props = data["results"][0]["properties"];
      _debugProperties(props);
    }

    return List<Map<String, dynamic>>.from(data["results"]);
  }

  // ---------------------------
  // 📌 DEBUG GENERALE
  // ---------------------------
  void _debugProperties(Map<String, dynamic> props) {
    props.forEach((key, value) {
      print("=== $key ===");
      print("type: ${value["type"]}");

      final snippet = jsonEncode(value);
      final safe = snippet.length > 400
          ? snippet.substring(0, 400) + " ...TRONCATO..."
          : snippet;

      print(safe);
      print("");
    });
  }

  // ---------------------------
  // 📌 DEBUG DI UNA PAGINA RELATION
  // ---------------------------
  Future<void> debugOneRelation(String pageId) async {
    print("====== DETTAGLIO PERSONA ($pageId) ======");

    final url = "https://api.notion.com/v1/pages/$pageId";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Notion-Version": "2022-06-28",
      },
    );

    if (res.statusCode != 200) {
      print("Errore debugOneRelation: ${res.body}");
      return;
    }

    final data = jsonDecode(res.body);
    print(jsonEncode(data));
  }

  /// Fetches the title of an arbitrary related page so we can show a readable
  /// name instead of the Notion relation ID.
  Future<String> fetchNameFromPage(String pageId) async {
    final url = "https://api.notion.com/v1/pages/$pageId";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Notion-Version": "2022-06-28",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Errore fetchNameFromPage: ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final props = data["properties"] as Map<String, dynamic>? ?? {};

    for (final value in props.values) {
      if (value is! Map<String, dynamic>) continue;
      if (value["type"] != "title") continue;

      final titles = value["title"] as List<dynamic>? ?? const [];
      if (titles.isEmpty) continue;

      final first = titles.first;
      if (first is Map<String, dynamic>) {
        final text = first["plain_text"];
        if (text is String && text.isNotEmpty) {
          return text;
        }
      }
    }

    return "";
  }
}
