import 'package:flutter/material.dart';

/// Shared elevation treatments for the small number of surfaces that
/// intentionally float above Bookly's otherwise flat interface.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> overlay(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: shadow.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> navigation(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ];

  static List<BoxShadow> activeIndicator(
    Color accent, {
    required bool active,
  }) =>
      [
        BoxShadow(
          color: accent.withValues(alpha: 0.30),
          blurRadius: active ? 16 : 8,
          spreadRadius: active ? 2 : 0,
        ),
      ];
}
