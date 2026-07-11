import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  static const _webProxyUrl =
      'https://rapporto-servizio-flutter.vercel.app/api/notion-query';
  final String databaseId;

  NotionService({required this.databaseId});

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
    while (true) {
      final payload = <String, dynamic>{'page_size': 100};
      if (cursor != null && cursor.isNotEmpty) {
        payload['start_cursor'] = cursor;
      }

      final res = await _postViaWebProxy({
        'action': 'queryDatabase',
        'databaseId': dbId,
        ...payload,
      });

      if (res.statusCode != 200) {
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

  /// Fetches the title of an arbitrary related page so we can show a readable
  /// name instead of the Notion relation ID.
  Future<String> fetchNameFromPage(String pageId) async {
    final res = await _postViaWebProxy({
      'action': 'retrievePage',
      'pageId': pageId,
    });

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

  Future<List<String>> fetchKronosDesignatiIds(String pageId) async {
    final res = await _postViaWebProxy({
      'action': 'retrievePage',
      'pageId': pageId,
    });

    if (res.statusCode != 200) {
      throw Exception('Errore fetchKronosDesignatiIds: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final props = data['properties'] as Map<String, dynamic>? ?? {};
    final kronos = props['KRONOS DESIGNATI'];
    if (kronos is! Map<String, dynamic>) return const [];

    final relation = kronos['relation'];
    if (relation is! List) return const [];

    final ids = <String>[];
    for (final entry in relation) {
      if (entry is Map<String, dynamic>) {
        final id = entry['id'];
        if (id is String && id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  Future<String> fetchDisponibilitaViaAppText(String pageId) async {
    final res = await _postViaWebProxy({
      'action': 'retrievePage',
      'pageId': pageId,
    });

    if (res.statusCode != 200) {
      throw Exception('Errore fetchDisponibilitaViaAppText: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final props = data['properties'] as Map<String, dynamic>? ?? {};
    final raw = props['DISPONIBILITA_VIA_APP'];
    if (raw is! Map<String, dynamic>) return '';

    final rich = raw['rich_text'];
    if (rich is! List || rich.isEmpty) return '';

    final buffer = StringBuffer();
    for (final entry in rich) {
      if (entry is Map<String, dynamic>) {
        final plain = entry['plain_text'];
        if (plain is String && plain.isNotEmpty) {
          buffer.write(plain);
        }
      }
    }
    return buffer.toString().trim();
  }

  Future<void> updateKronosDesignati(
    String pageId,
    List<String> kronosIds, {
    String disponibilitaViaApp = '',
  }) async {
    final body = jsonEncode({
      'properties': {
        'KRONOS DESIGNATI': {
          'relation': kronosIds.map((id) => {'id': id}).toList(),
        },
        'DISPONIBILITA_VIA_APP': {
          'rich_text': disponibilitaViaApp.trim().isEmpty
              ? <Map<String, dynamic>>[]
              : [
                  {
                    'type': 'text',
                    'text': {'content': disponibilitaViaApp.trim()},
                  }
                ],
        },
      }
    });

    final res = await _postViaWebProxy({
      'action': 'updatePage',
      'pageId': pageId,
      'payload': jsonDecode(body),
    });

    if (res.statusCode != 200) {
      throw Exception('Errore aggiornamento gara: ${res.body}');
    }
  }

  Future<void> notifyAdminsAvailability({
    required String garaId,
    required String garaTitolo,
    required String userId,
    required String userName,
  }) async {
    final payload = jsonEncode({
      'action': 'notifyAdminsAvailability',
      'garaId': garaId,
      'garaTitolo': garaTitolo,
      'userId': userId,
      'userName': userName,
    });

    final res = await http.post(
      Uri.parse(_webProxyUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: payload,
    );

    if (res.statusCode != 200) {
      throw Exception('Errore notifica admin: ${res.body}');
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
    return _postViaWebProxy({
      'action': 'updatePage',
      'pageId': pageId,
      'payload': payload,
    });
  }

  Future<http.Response> _postViaWebProxy(Map<String, dynamic> payload) async {
    final body = jsonEncode(payload);
    final res = await http.post(
      Uri.parse(_webProxyUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    return res;
  }
}
