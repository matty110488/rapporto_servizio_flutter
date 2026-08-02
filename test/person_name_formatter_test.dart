import 'package:flutter_test/flutter_test.dart';
import 'package:rapporto_servizio/constants/cronometristi.dart';
import 'package:rapporto_servizio/utils/person_name_formatter.dart';

void main() {
  group('formatPersonName', () {
    test('restores the apostrophe in the historical Dell Olio entry', () {
      expect(formatPersonName('DELL OLIO Cosimo'), "Dell'Olio Cosimo");
      expect(formatPersonName('Cosimo dell olio'), "Cosimo Dell'Olio");
    });

    test('normalizes typographic apostrophes and capitalization', () {
      expect(formatPersonName('dell’olio COSIMO'), "Dell'Olio Cosimo");
      expect(formatPersonName("d'angelo ANNA-MARIA"), "D'Angelo Anna-Maria");
    });

    test('capitalizes every component and removes extra spaces', () {
      expect(formatPersonName('  DEI   CAS MARCO  '), 'Dei Cas Marco');
    });
  });

  test('the timekeeper list contains the corrected name', () {
    expect(availableCronometristi, contains("Dell'Olio Cosimo"));
    expect(availableCronometristi, isNot(contains('DELL OLIO Cosimo')));
  });
}
