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
  // QUERY DATABASE
  // ---------------------------
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
  }) async {
    final ids = <String>{
      databaseId,
      ...additionalDatabaseIds.where((id) => id.isNotEmpty),
    };
    final List<Map<String, dynamic>> all = [];
    for (final id in ids) {
      all.addAll(await _fetchGareFromDatabase(id));
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchGareFromDatabase(String dbId) async {
    final url = 'https://api.notion.com/v1/databases/$dbId/query';
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Notion-Version': '2022-06-28',
    };

    final all = <Map<String, dynamic>>[];
    String? cursor;
    var firstPage = true;

    while (true) {
      final payload = <String, dynamic>{'page_size': 100};
      if (cursor != null && cursor.isNotEmpty) {
        payload['start_cursor'] = cursor;
      }

      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        print('STATUS CODE: ${res.statusCode}');
        print('BODY: ${res.body}');
        // Se il database non e condiviso con l'integrazione o l'ID e errato,
        // evitiamo di bloccare l'app e proseguiamo con gli altri database.
        if (res.statusCode == 404) {
          return [];
        }
        throw Exception('Errore Notion: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final pageResults = List<Map<String, dynamic>>.from(
        (data['results'] as List<dynamic>? ?? const []),
      );
      all.addAll(pageResults);

      // Debug solo sulla prima pagina per evitare log eccessivo.
      if (firstPage && pageResults.isNotEmpty) {
        print('\n=== DEBUG PROPERTIES ($dbId) ===');
        final props = pageResults.first['properties'];
        if (props is Map<String, dynamic>) {
          _debugProperties(props);
        }
      }
      firstPage = false;

      final hasMore = data['has_more'] == true;
      if (!hasMore) break;

      final nextCursor = data['next_cursor'];
      if (nextCursor is String && nextCursor.isNotEmpty) {
        cursor = nextCursor;
      } else {
        break;
      }
    }

    return all;
  }

  // ---------------------------
  // DEBUG GENERALE
  // ---------------------------
  void _debugProperties(Map<String, dynamic> props) {
    props.forEach((key, value) {
      print('=== $key ===');
      print('type: ${value["type"]}');

      final snippet = jsonEncode(value);
      final safe = snippet.length > 400
          ? '${snippet.substring(0, 400)} ...TRONCATO...'
          : snippet;

      print(safe);
      print('');
    });
  }

  // ---------------------------
  // DEBUG DI UNA PAGINA RELATION
  // ---------------------------
  Future<void> debugOneRelation(String pageId) async {
    print('====== DETTAGLIO PERSONA ($pageId) ======');

    final url = 'https://api.notion.com/v1/pages/$pageId';

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Notion-Version': '2022-06-28',
      },
    );

    if (res.statusCode != 200) {
      print('Errore debugOneRelation: ${res.body}');
      return;
    }

    final data = jsonDecode(res.body);
    print(jsonEncode(data));
  }

  /// Fetches the title of an arbitrary related page so we can show a readable
  /// name instead of the Notion relation ID.
  Future<String> fetchNameFromPage(String pageId) async {
    final url = 'https://api.notion.com/v1/pages/$pageId';

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Notion-Version': '2022-06-28',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Errore fetchNameFromPage: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final props = data['properties'] as Map<String, dynamic>? ?? {};

    for (final value in props.values) {
      if (value is! Map<String, dynamic>) continue;
      if (value['type'] != 'title') continue;

      final titles = value['title'] as List<dynamic>? ?? const [];
      if (titles.isEmpty) continue;

      final first = titles.first;
      if (first is Map<String, dynamic>) {
        final text = first['plain_text'];
        if (text is String && text.isNotEmpty) {
          return text;
        }
      }
    }

    return '';
  }

  Future<void> updateKronosDesignati(
      String pageId, List<String> kronosIds) async {
    final url = 'https://api.notion.com/v1/pages/$pageId';
    final body = jsonEncode({
      'properties': {
        'KRONOS DESIGNATI': {
          'relation': kronosIds.map((id) => {'id': id}).toList(),
        }
      }
    });

    final res = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('Errore aggiornamento gara: ${res.body}');
    }
  }
}
