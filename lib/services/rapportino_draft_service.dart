import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
}
