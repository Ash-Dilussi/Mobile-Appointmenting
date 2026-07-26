/// Phone number utility functions for normalized comparison.
///
/// This module provides consistent phone number matching across the app,
/// handling various formats (with spaces, dashes, country codes, etc.)
/// by normalizing to a common format before comparison.

/// Normalizes a phone number for comparison purposes.
///
/// Strips all non-digit characters. If the result is longer than 10 digits,
/// keeps only the last 10 digits (handles international numbers like
/// +1 555 123 4567, 15551234567, 5551234567 all matching to 5551234567).
///
/// For numbers shorter than 10 digits (e.g., short codes, extensions),
/// keeps them as-is since they may be valid short numbers.
String normalizePhoneNumber(String raw) {
  if (raw.isEmpty) return raw;

  // Strip everything except digits
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

  if (digitsOnly.isEmpty) return raw;

  // If longer than 10 digits, keep only the last 10
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
