import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RapportinoDraftSummary {
  final String draftId;
  final String title;
  final String dateLabel;
  final DateTime updatedAt;
  final String primaryGaraId;
  final bool wholePackage;

  const RapportinoDraftSummary({
    required this.draftId,
    required this.title,
    required this.dateLabel,
    required this.updatedAt,
    required this.primaryGaraId,
    required this.wholePackage,
  });
}

class RapportinoDraftService {
  static const _prefix = 'rapportino_draft_v1_';

  String _key(String garaId) => '$_prefix$garaId';

  Future<void> saveDraft(String garaId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(garaId), jsonEncode(payload));
  }

  Future<Map<String, dynamic>?> loadDraft(String garaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(garaId));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<List<RapportinoDraftSummary>> listDrafts({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final summaries = <RapportinoDraftSummary>[];

    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final data = Map<String, dynamic>.from(decoded);
        final storedUserId = (data['userId'] ?? '').toString();
        if (userId != null &&
            storedUserId.isNotEmpty &&
            storedUserId != userId) {
          continue;
        }

        final draftId = key.substring(_prefix.length);
        final gara = data['gara'] is Map
            ? Map<String, dynamic>.from(data['gara'] as Map)
            : <String, dynamic>{};
        final updatedAt = DateTime.tryParse(
              (data['updatedAt'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final primaryGaraId = (data['primaryGaraId'] ?? '').toString().trim();
        final fallbackGaraId = draftId.contains(':') ? '' : draftId;

        summaries.add(
          RapportinoDraftSummary(
            draftId: draftId,
            title: (data['title'] ?? gara['nome'] ?? 'Rapportino senza nome')
                .toString(),
            dateLabel: (data['dateLabel'] ?? '').toString(),
            updatedAt: updatedAt,
            primaryGaraId:
                primaryGaraId.isNotEmpty ? primaryGaraId : fallbackGaraId,
            wholePackage: data['wholePackage'] == true,
          ),
        );
      } catch (_) {
        // Ignore a damaged local draft without blocking the other entries.
      }
    }

    summaries
        .sort((first, second) => second.updatedAt.compareTo(first.updatedAt));
    return summaries;
  }

  Future<void> deleteDraft(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(draftId));
  }
}
