import 'package:bookly/core/utils/age_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ageOnDate', () {
    test('subtracts a year before the birthday', () {
      expect(ageOnDate(DateTime(2000, 10, 20), DateTime(2026, 9, 6)), 25);
    });

    test('includes the birthday on and after its date', () {
      expect(ageOnDate(DateTime(2000, 9, 6), DateTime(2026, 9, 6)), 26);
      expect(ageOnDate(DateTime(2000, 9, 6), DateTime(2026, 9, 7)), 26);
    });

    test('handles February 29 birthdays in a non-leap year', () {
      expect(ageOnDate(DateTime(2000, 2, 29), DateTime(2026, 2, 28)), 25);
      expect(ageOnDate(DateTime(2000, 2, 29), DateTime(2026, 3, 1)), 26);
    });
  });
}
