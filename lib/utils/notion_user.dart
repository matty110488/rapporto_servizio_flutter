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
