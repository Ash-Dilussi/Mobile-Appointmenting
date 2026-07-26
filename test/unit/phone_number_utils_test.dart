import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/utils/phone_number_utils.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('returns empty string for empty input', () {
      expect(normalizePhoneNumber(''), '');
    });

    test('handles identical formats', () {
      expect(normalizePhoneNumber('5551234567'), '5551234567');
    });

    test('strips spaces, dashes, and parentheses', () {
      expect(normalizePhoneNumber('555-123-4567'), '5551234567');
      expect(normalizePhoneNumber('(555) 123-4567'), '5551234567');
      expect(normalizePhoneNumber('555 123 4567'), '5551234567');
    });

    test('handles leading + country code', () {
      expect(normalizePhoneNumber('+1 555 123 4567'), '5551234567');
      expect(normalizePhoneNumber('+94 77 123 4567'), '771234567');
    });

    test('keeps last 10 digits for long numbers', () {
      expect(normalizePhoneNumber('15551234567'), '5551234567');
      expect(normalizePhoneNumber('+1 555 123 4567'), '5551234567');
    });

    test('keeps short numbers as-is (less than 10 digits)', () {
      expect(normalizePhoneNumber('1234'), '1234');
      expect(normalizePhoneNumber('911'), '911');
    });

    test('handles Sri Lankan format with 94 country code', () {
      expect(normalizePhoneNumber('+94 77 123 4567'), '771234567');
      expect(normalizePhoneNumber('0094 77 123 4567'), '771234567');
      expect(normalizePhoneNumber('077 123 4567'), '771234567');
    });
  });

  group('phoneNumbersMatch', () {
    test('returns false for empty strings', () {
      expect(phoneNumbersMatch('', ''), false);
      expect(phoneNumbersMatch('5551234567', ''), false);
      expect(phoneNumbersMatch('', '5551234567'), false);
    });

    test('matches identical formats', () {
      expect(phoneNumbersMatch('5551234567', '5551234567'), true);
    });

    test('matches differently formatted numbers', () {
      expect(phoneNumbersMatch('555-123-4567', '5551234567'), true);
      expect(phoneNumbersMatch('(555) 123-4567', '5551234567'), true);
      expect(phoneNumbersMatch('+1 555 123 4567', '5551234567'), true);
    });

    test('matches numbers with country codes', () {
      expect(phoneNumbersMatch('+1 555 123 4567', '15551234567'), true);
      expect(phoneNumbersMatch('+94 77 123 4567', '771234567'), true);
    });

    test('does not match different numbers', () {
      expect(phoneNumbersMatch('5551234567', '5551234568'), false);
      expect(phoneNumbersMatch('5551234567', '5550000000'), false);
    });
  });
}
