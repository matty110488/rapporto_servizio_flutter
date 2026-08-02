import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/app_environment.dart';
import '../state/session_state.dart';
import '../utils/person_name_formatter.dart';

class NotionPersonContact {
  const NotionPersonContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class NotionService {
  final String databaseId;

  static final Map<String, _RaceDatabaseCacheEntry> _raceDatabaseCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _raceDatabaseRequests = {};

  NotionService({required this.databaseId});

  // ---------------------------
  // QUERY DATABASE
  // ---------------------------
  Future<List<Map<String, dynamic>>> fetchGare({
    List<String> additionalDatabaseIds = const [],
    bool forceRefresh = false,
  }) async {
    final ids = <String>{
      databaseId,
      ...additionalDatabaseIds.where((id) => id.isNotEmpty),
    };
    final List<Map<String, dynamic>> all = [];
    for (final id in ids) {
      all.addAll(
        await _fetchCachedGareFromDatabase(id, forceRefresh: forceRefresh),
      );
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchCachedGareFromDatabase(
    String dbId, {
    required bool forceRefresh,
  }) async {
    final now = DateTime.now();
    final cached = _raceDatabaseCache[dbId];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.loadedAt) < AppConfig.raceDatabaseCacheDuration) {
      return cached.rows;
    }

    final pending = _raceDatabaseRequests[dbId];
    if (pending != null) return pending;

    final request = _fetchGareFromDatabase(dbId);
    _raceDatabaseRequests[dbId] = request;
    try {
      final rows = await request;
      _raceDatabaseCache[dbId] = _RaceDatabaseCacheEntry(
        rows: rows,
        loadedAt: DateTime.now(),
      );
      return rows;
    } finally {
      if (identical(_raceDatabaseRequests[dbId], request)) {
        _raceDatabaseRequests.remove(dbId);
      }
    }
  }

  static void invalidateRaceDatabaseCache() {
    _raceDatabaseCache.clear();
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

  /// Loads only report-bearing races the signed-in user may view.
  ///
  /// The server authorizes each result against the race DSC relation, while
  /// administrators may view every report.
  Future<List<Map<String, dynamic>>> fetchReportArchive() async {
    final res = await _postViaWebProxy({
      'action': 'queryReportArchive',
      'databaseId': databaseId,
    });
    if (res.statusCode != 200) {
      throw Exception('Errore archivio Notion: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(
      data['results'] as List<dynamic>? ?? const [],
    );
  }

  /// Fetches the title of an arbitrary related page so we can show a readable
  /// name instead of the Notion relation ID.
  Future<String> fetchNameFromPage(String pageId) async {
    return (await fetchPersonContactFromPage(pageId)).name;
  }

  Future<NotionPersonContact> fetchPersonContactFromPage(String pageId) async {
    final res = await _postViaWebProxy({
      'action': 'retrievePage',
      'pageId': pageId,
    });

    if (res.statusCode != 200) {
      throw Exception('Errore fetchPersonContactFromPage: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final props = data['properties'] as Map<String, dynamic>? ?? {};

    var name = '';
    for (final value in props.values) {
      if (value is! Map<String, dynamic>) continue;
      if (value['type'] != 'title') continue;

      final titles = value['title'] as List<dynamic>? ?? const [];
      if (titles.isEmpty) continue;

      final first = titles.first;
      if (first is Map<String, dynamic>) {
        final text = first['plain_text'];
        if (text is String && text.isNotEmpty) {
          name = text.trim();
          break;
        }
      }
    }

    String readPhone(Object? raw) {
      if (raw is! Map) return '';
      final phone = raw['phone_number'];
      if (phone is String && phone.trim().isNotEmpty) return phone.trim();
      final richText = raw['rich_text'];
      if (richText is List) {
        final text = richText
            .whereType<Map>()
            .map((item) => item['plain_text']?.toString() ?? '')
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
      final formula = raw['formula'];
      if (formula is Map) {
        final text = formula['string'];
        if (text is String && text.trim().isNotEmpty) return text.trim();
      }
      return '';
    }

    const phoneKeys = [
      'TELEFONO',
      'Telefono',
      'telefono',
      'CELLULARE',
      'Cellulare',
      'cellulare',
      'PHONE',
      'Phone',
      'phone',
      'MOBILE',
      'Mobile',
      'WHATSAPP',
      'WhatsApp',
    ];
    var phone = '';
    for (final key in phoneKeys) {
      phone = readPhone(props[key]);
      if (phone.isNotEmpty) break;
    }
    if (phone.isEmpty) {
      for (final value in props.values) {
        if (value is Map && value['type'] == 'phone_number') {
          phone = readPhone(value);
          if (phone.isNotEmpty) break;
        }
      }
    }

    return NotionPersonContact(name: formatPersonName(name), phone: phone);
  }

  Future<Map<String, dynamic>> retrievePage(String pageId) async {
    final res = await _postViaWebProxy({
      'action': 'retrievePage',
      'pageId': pageId,
    });

    if (res.statusCode != 200) {
      throw Exception('Errore retrievePage: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
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
    invalidateRaceDatabaseCache();
  }

  Future<AdminNotificationResult> notifyAdminsAvailability({
    required String garaId,
    required String garaTitolo,
    required String userId,
    required String userName,
    required bool available,
  }) async {
    final payload = {
      'action': 'notifyAdminsAvailability',
      'garaId': garaId,
      'garaTitolo': garaTitolo,
      'userId': userId,
      'userName': userName,
      'available': available,
    };

    final res = await _postViaWebProxy(payload);

    if (res.statusCode != 200) {
      throw Exception('Errore notifica admin: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminNotificationResult.fromJson(data);
  }

  Future<DesignationNotificationScanResult>
      notifyDesignationsForSentStatus() async {
    final res = await _postViaWebProxy({
      'action': 'notifyDesignationsForSentStatus',
    });

    if (res.statusCode != 200) {
      throw Exception('Errore notifica designazioni: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DesignationNotificationScanResult.fromJson(data);
  }

  Future<void> updateGaraStatus(String pageId, String statusName) async {
    final statusPayload = {
      'properties': {
        NotionRaceProperties.status: {
          'status': {'name': statusName}
        }
      }
    };

    final selectPayload = {
      'properties': {
        NotionRaceProperties.status: {
          'select': {'name': statusName}
        }
      }
    };

    final primary = await _patchPage(pageId, statusPayload);
    if (primary.statusCode == 200) {
      invalidateRaceDatabaseCache();
      return;
    }

    final fallback = await _patchPage(pageId, selectPayload);
    if (fallback.statusCode != 200) {
      throw Exception('Errore aggiornamento status gara: ${fallback.body}');
    }
    invalidateRaceDatabaseCache();
  }

  /// Archives a completed report in the race pages' `Files & media` field.
  /// Returns false when the PDF is deliberately skipped because it is too big.
  Future<bool> archiveReportPdf({
    required List<int> pdfBytes,
    required List<String> pageIds,
    required String filename,
  }) async {
    if (pdfBytes.length > AppConfig.maxNotionPdfBytes) return false;
    final uniquePageIds = pageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniquePageIds.isEmpty) return false;

    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Sessione scaduta: effettua nuovamente il login.');
    }
    final uploadUrl = apiUrl.endsWith('/notion-query')
        ? '${apiUrl.substring(0, apiUrl.length - '/notion-query'.length)}/notion-file-upload'
        : '$apiUrl/notion-file-upload';
    final encodedFilename =
        base64Url.encode(utf8.encode(filename)).replaceAll('=', '');
    final response = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': 'application/pdf',
        'Authorization': 'Bearer $sessionToken',
        'X-Notion-Page-Ids': uniquePageIds.join(','),
        'X-Report-Filename': encodedFilename,
      },
      body: pdfBytes,
    );
    await throwIfSessionExpiredResponse(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Errore archiviazione PDF: ${response.body}');
    }
    invalidateRaceDatabaseCache();
    return true;
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
    final sessionToken = globalSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Sessione scaduta: effettua nuovamente il login.');
    }
    final res = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionToken',
      },
      body: body,
    );
    await throwIfSessionExpiredResponse(res.statusCode);

    return res;
  }
}

class _RaceDatabaseCacheEntry {
  const _RaceDatabaseCacheEntry({required this.rows, required this.loadedAt});

  final List<Map<String, dynamic>> rows;
  final DateTime loadedAt;
}

class AdminNotificationResult {
  const AdminNotificationResult({
    required this.sent,
    required this.attempted,
    this.reason = '',
    this.errors = const [],
  });

  final int sent;
  final int attempted;
  final String reason;
  final List<String> errors;

  factory AdminNotificationResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return AdminNotificationResult(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      reason: json['reason'] is String ? json['reason'] as String : '',
      errors: rawErrors is List
          ? rawErrors.map((entry) => entry.toString()).toList()
          : const [],
    );
  }
}

class DesignationNotificationScanResult {
  const DesignationNotificationScanResult({
    required this.sent,
    required this.attempted,
    required this.checked,
  });

  final int sent;
  final int attempted;
  final int checked;

  factory DesignationNotificationScanResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return DesignationNotificationScanResult(
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      checked: (json['checked'] as num?)?.toInt() ?? 0,
    );
  }
}
