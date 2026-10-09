import 'package:bookly/core/constants/auth_field_constraints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthFieldConstraints', () {
    test('uses the requested field lengths', () {
      expect(AuthFieldConstraints.fullNameMaxLength, 50);
      expect(AuthFieldConstraints.emailMaxLength, 75);
      expect(AuthFieldConstraints.passwordMinLength, 8);
    });

    test('rejects a password shorter than eight characters', () {
      expect(
        AuthFieldConstraints.validatePassword('1234567'),
        'Password must be at least 8 characters',
      );
      expect(AuthFieldConstraints.validatePassword('12345678'), isNull);
    });

    test('rejects blank names and malformed email addresses', () {
      expect(AuthFieldConstraints.validateFullName('   '), isNotNull);
      expect(AuthFieldConstraints.validateEmail('person@example'), isNotNull);
      expect(AuthFieldConstraints.validateEmail('person@example.com'), isNull);
    });
  });
}
