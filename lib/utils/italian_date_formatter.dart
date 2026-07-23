import 'package:intl/intl.dart';

const italianShortWeekdays = [
  'LUN',
  'MAR',
  'MER',
  'GIO',
  'VEN',
  'SAB',
  'DOM',
];

String italianShortWeekday(DateTime date) =>
    italianShortWeekdays[date.weekday - 1];

String formatItalianDate(DateTime date, {bool includeYear = true}) {
  final pattern = includeYear ? 'dd/MM/yyyy' : 'dd/MM';
  return '${italianShortWeekday(date)} ${DateFormat(pattern).format(date)}';
}

String? formatItalianIsoDate(String value, {bool includeYear = true}) {
  final date = DateTime.tryParse(value);
  return date == null
      ? null
      : formatItalianDate(date, includeYear: includeYear);
}

String formatItalianIsoDateOrValue(
  String value, {
  bool includeYear = true,
  String emptyValue = '-',
}) {
  if (value.trim().isEmpty) return emptyValue;
  return formatItalianIsoDate(value, includeYear: includeYear) ?? value;
}

String addItalianWeekdaysToDateLabel(String value) {
  final datePattern = RegExp(r'\b(\d{2})/(\d{2})/(\d{4})\b');
  return value.replaceAllMapped(datePattern, (match) {
    final prefixStart = match.start >= 4 ? match.start - 4 : 0;
    final prefix = value.substring(prefixStart, match.start);
    if (RegExp(r'[A-Z]{3} $').hasMatch(prefix)) return match.group(0)!;

    final date = DateTime.tryParse(
      '${match.group(3)}-${match.group(2)}-${match.group(1)}',
    );
    return date == null
        ? match.group(0)!
        : '${italianShortWeekday(date)} ${match.group(0)}';
  });
}
