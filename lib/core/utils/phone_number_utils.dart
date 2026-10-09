/// Phone number utility functions for normalized comparison.
///
/// This module provides consistent phone number matching across the app,
/// handling various formats (with spaces, dashes, country codes, etc.)
/// by normalizing to a common format before comparison.
library;

/// Normalizes a phone number for comparison purposes.
///
/// Strips all non-digit characters and canonicalizes the formats used by the
/// app. Sri Lankan `+94`/`0094` and local trunk-prefix (`0`) numbers normalize
/// to the same nine-digit subscriber value. North American country-prefix
/// (`1`) numbers normalize to ten digits. Other long values use the last ten
/// digits as a conservative comparison fallback.
///
/// For numbers shorter than 10 digits (e.g., short codes, extensions),
/// keeps them as-is since they may be valid short numbers.
String normalizePhoneNumber(String raw) {
  if (raw.isEmpty) return raw;

  // Strip everything except digits
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

  if (digitsOnly.isEmpty) return raw;

  if (digitsOnly.startsWith('0094') && digitsOnly.length == 13) {
    return digitsOnly.substring(4);
  }

  if (digitsOnly.startsWith('94') && digitsOnly.length == 11) {
    return digitsOnly.substring(2);
  }

  if (digitsOnly.startsWith('0') && digitsOnly.length == 10) {
    return digitsOnly.substring(1);
  }

  if (digitsOnly.startsWith('1') && digitsOnly.length == 11) {
    return digitsOnly.substring(1);
  }

  if (digitsOnly.length > 10) {
    return digitsOnly.substring(digitsOnly.length - 10);
  }

  return digitsOnly;
}

/// Compares two phone numbers for equality after normalization.
///
/// Returns true if both numbers normalize to the same value AND both are non-empty.
/// Returns false if either number is empty after normalization.
bool phoneNumbersMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;

  final normalizedA = normalizePhoneNumber(a);
  final normalizedB = normalizePhoneNumber(b);

  if (normalizedA.isEmpty || normalizedB.isEmpty) return false;

  return normalizedA == normalizedB;
}
