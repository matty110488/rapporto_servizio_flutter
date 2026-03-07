import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotionService {
  static const _webProxyUrl =
      'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
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
    final all = <Map<String, dynamic>>[];
    String? cursor;
    var firstPage = true;

    while (true) {
      final payload = <String, dynamic>{'page_size': 100};
      if (cursor != null && cursor.isNotEmpty) {
        payload['start_cursor'] = cursor;
      }

      final res = kIsWeb
          // Web-only: query database via proxy Vercel.
          ? await _postViaWebProxy({
              'action': 'queryDatabase',
              'databaseId': dbId,
              ...payload,
            })
          : await http.post(
              Uri.parse('https://api.notion.com/v1/databases/$dbId/query'),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
                'Notion-Version': '2022-06-28',
              },
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

    final res = kIsWeb
        // Web-only: lettura pagina via proxy Vercel.
        ? await _postViaWebProxy({
            'action': 'retrievePage',
            'pageId': pageId,
          })
        : await http.get(
            Uri.parse('https://api.notion.com/v1/pages/$pageId'),
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
    final res = kIsWeb
        // Web-only: lettura pagina via proxy Vercel.
        ? await _postViaWebProxy({
            'action': 'retrievePage',
            'pageId': pageId,
          })
        : await http.get(
            Uri.parse('https://api.notion.com/v1/pages/$pageId'),
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
    final body = jsonEncode({
      'properties': {
        'KRONOS DESIGNATI': {
          'relation': kronosIds.map((id) => {'id': id}).toList(),
        }
      }
    });

    final res = kIsWeb
        // Web-only: update pagina via proxy Vercel.
        ? await _postViaWebProxy({
            'action': 'updatePage',
            'pageId': pageId,
            'payload': jsonDecode(body),
          })
        : await http.patch(
            Uri.parse('https://api.notion.com/v1/pages/$pageId'),
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

  Future<void> updateGaraStatus(String pageId, String statusName) async {
    final statusPayload = {
      'properties': {
        'STATUS': {
          'status': {'name': statusName}
        }
      }
    };

    final selectPayload = {
      'properties': {
        'STATUS': {
          'select': {'name': statusName}
        }
      }
    };

    final primary = await _patchPage(pageId, statusPayload);
    if (primary.statusCode == 200) return;

    final fallback = await _patchPage(pageId, selectPayload);
    if (fallback.statusCode != 200) {
      throw Exception('Errore aggiornamento status gara: ${fallback.body}');
    }
  }

  Future<http.Response> _patchPage(
    String pageId,
    Map<String, dynamic> payload,
  ) async {
    final body = jsonEncode(payload);
    return kIsWeb
        // Web-only: update pagina via proxy Vercel.
        ? _postViaWebProxy({
            'action': 'updatePage',
            'pageId': pageId,
            'payload': payload,
          })
        : http.patch(
            Uri.parse('https://api.notion.com/v1/pages/$pageId'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Notion-Version': '2022-06-28',
              'Content-Type': 'application/json',
            },
            body: body,
          );
  }

  Future<http.Response> _postViaWebProxy(Map<String, dynamic> payload) async {
    final body = jsonEncode(payload);
    // Web-only: endpoint proxy che applica auth verso Notion lato server.
    print('[WEB][NotionService] Request URL: $_webProxyUrl');
    print('[WEB][NotionService] Request body: $body');

    final res = await http.post(
      Uri.parse(_webProxyUrl),
      headers: {
        // Web-only: niente Authorization/Notion-Version dal client.
        'Content-Type': 'application/json',
      },
      body: body,
    );

    print('[WEB][NotionService] Response body: ${res.body}');
    return res;
  }
}
