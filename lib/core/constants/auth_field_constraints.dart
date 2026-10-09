abstract final class AuthFieldConstraints {
  static const int fullNameMaxLength = 50;
  static const int emailMaxLength = 75;
  static const int passwordMinLength = 8;

  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    return null;
  }
}
