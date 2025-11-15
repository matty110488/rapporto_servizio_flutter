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
  // 📌 QUERY AL DATABASE GARE
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
    return List<Map<String, dynamic>>.from(data["results"]);
  }

  // ---------------------------
  // 📌 LETTURA SINGOLA PAGINA
  // ---------------------------
  Future<Map<String, dynamic>> fetchPage(String pageId) async {
    final url = "https://api.notion.com/v1/pages/$pageId";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Notion-Version": "2022-06-28",
      },
    );

    if (res.statusCode != 200) {
      print("Errore fetchPage: ${res.body}");
      throw Exception("Errore Notion fetchPage");
    }

    return jsonDecode(res.body);
  }

  // -----------------------------------------
  // 📌 RECUPERA IL NOME DAL TITOLO DELLA PAGINA
  // -----------------------------------------
  Future<String> fetchNameFromPage(String pageId) async {
    final page = await fetchPage(pageId);

    final props = page["properties"];
    if (props == null) return "";

    // Cerca una proprietà di tipo "title"
    for (final entry in props.entries) {
      final value = entry.value;

      if (value["type"] == "title") {
        final list = value["title"];
        if (list != null && list.isNotEmpty) {
          return list[0]["plain_text"] ?? "";
        }
      }
    }

    return "";
  }
}
