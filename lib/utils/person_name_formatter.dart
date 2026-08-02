String formatPersonName(Object? value) {
  var name = (value ?? '').toString().trim();
  if (name.isEmpty) return '';

  name = name
      .replaceAll(RegExp(r'[\u2018\u2019\u02BC\u02BB\u0060\u00B4]'), "'")
      .replaceAll(RegExp(r'\s+'), ' ');

  // Corregge il nominativo storico presente nell'elenco e nelle vecchie bozze.
  name = name.replaceFirst(
    RegExp(r'\bdell\s+olio\b', caseSensitive: false),
    "Dell'Olio",
  );

  final result = StringBuffer();
  var capitalizeNext = true;
  for (final rune in name.runes) {
    final character = String.fromCharCode(rune);
    if (character == ' ' || character == "'" || character == '-') {
      result.write(character);
      capitalizeNext = true;
      continue;
    }
    result.write(
        capitalizeNext ? character.toUpperCase() : character.toLowerCase());
    capitalizeNext = false;
  }
  return result.toString();
}
