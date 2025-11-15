import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  final String apiKey;
  final String databaseId;

  NotionService({
    required this.apiKey,
    required this.databaseId,
  });

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
      throw Exception("Errore Notion: ${res.body}");
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data["results"]);
  }
}
