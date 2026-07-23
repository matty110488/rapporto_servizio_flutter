import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/utils/italian_date_formatter.dart';

void main() {
  test('formats every Italian short weekday correctly', () {
    final monday = DateTime(2026, 7, 20);
    expect(
      List.generate(
        7,
        (index) => formatItalianDate(monday.add(Duration(days: index))),
      ),
      [
        'LUN 20/07/2026',
        'MAR 21/07/2026',
        'MER 22/07/2026',
        'GIO 23/07/2026',
        'VEN 24/07/2026',
        'SAB 25/07/2026',
        'DOM 26/07/2026',
      ],
    );
  });

  test('keeps invalid values and supports dates without a year', () {
    expect(formatItalianIsoDate('2026-07-22'), 'MER 22/07/2026');
    expect(
      formatItalianIsoDate('2026-07-22', includeYear: false),
      'MER 22/07',
    );
    expect(formatItalianIsoDateOrValue('data da definire'), 'data da definire');
  });

  test('adds weekdays to persisted date labels without duplicating them', () {
    expect(
      addItalianWeekdaysToDateLabel('22/07/2026, 23/07/2026'),
      'MER 22/07/2026, GIO 23/07/2026',
    );
    expect(
      addItalianWeekdaysToDateLabel('MER 22/07/2026'),
      'MER 22/07/2026',
    );
  });
}
