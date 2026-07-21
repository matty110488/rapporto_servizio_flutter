String extractNotionUserName(Map<String, dynamic> user) {
  final props = user['properties'];
  if (props is! Map<String, dynamic>) return 'Utente';

  String readText(dynamic value) {
    if (value is! Map<String, dynamic>) return '';
    final type = value['type'];
    final items = type == 'title'
        ? value['title']
        : type == 'rich_text'
            ? value['rich_text']
            : null;
    if (items is! List) return '';
    return items
        .whereType<Map>()
        .map((item) => (item['plain_text'] ?? '').toString())
        .join()
        .trim();
  }

  const preferredKeys = [
    'NOME E COGNOME',
    'NOME',
    'NAME',
    'USERNAME',
  ];
  for (final key in preferredKeys) {
    final text = readText(props[key]);
    if (text.isNotEmpty) return text;
  }

  for (final value in props.values) {
    if (value is Map<String, dynamic> && value['type'] == 'title') {
      final text = readText(value);
      if (text.isNotEmpty) return text;
    }
  }
  return 'Utente';
}

bool isNotionAdmin(Map<String, dynamic> user) {
  final props = user['properties'];
  if (props is! Map<String, dynamic>) return false;

  bool isAdminText(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'admin' || normalized == 'amministratore';
  }

  bool isAdminField(Object? value) {
    if (value is! Map<String, dynamic>) return false;
    if (value['checkbox'] == true) return true;
    final select = value['select'];
    if (select is Map && isAdminText(select['name'])) return true;
    final multiSelect = value['multi_select'];
    if (multiSelect is List &&
        multiSelect.whereType<Map>().any((item) => isAdminText(item['name']))) {
      return true;
    }
    final richText = value['rich_text'];
    if (richText is List &&
        richText
            .whereType<Map>()
            .any((item) => isAdminText(item['plain_text']))) {
      return true;
    }
    return false;
  }

  const adminKeys = [
    'ADMIN',
    'Admin',
    'admin',
    'RUOLO',
    'Ruolo',
    'ROLE',
    'Role',
    'role',
  ];
  return adminKeys.any((key) => isAdminField(props[key]));
}
