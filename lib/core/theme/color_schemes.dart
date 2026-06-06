import 'package:flutter/material.dart';
import 'style_preset.dart';

/// Maps StylePreset enum to ColorScheme definitions.
class AppColorSchemes {
  AppColorSchemes._();

  /// Get ColorScheme for a given preset and brightness.
  static ColorScheme getColorScheme(StylePreset preset, Brightness brightness) {
    switch (preset) {
      case StylePreset.solarOrange:
        return _solarOrange(brightness);
      case StylePreset.clinicTeal:
        return _clinicTeal(brightness);
      case StylePreset.midnightCharcoal:
        return _midnightCharcoal(brightness);
      case StylePreset.forestGreen:
        return _forestGreen(brightness);
      case StylePreset.royalPurple:
        return _royalPurple(brightness);
    }
  }

  // Solar Orange (default) - warm, inviting, energetic
  static ColorScheme _solarOrange(Brightness brightness) {
    return brightness == Brightness.light
        ? const ColorScheme.light(
            primary: Color(0xFF904D00),
            primaryContainer: Color(0xFFFF8C00),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF5F5E5E),
            secondaryContainer: Color(0xFFE8E8E8),
            surface: Color(0xFFF9F9F9),
            surfaceContainerLowest: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFFFF8C00),
            primaryContainer: Color(0xFF904D00),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFFBDBDBD),
            secondaryContainer: Color(0xFF424242),
            surface: Color(0xFF121212),
            surfaceContainerLowest: Color(0xFF1E1E1E),
          );
  }

  // Clinic Teal - professional, trustworthy, healthcare aesthetic
  static ColorScheme _clinicTeal(Brightness brightness) {
    return brightness == Brightness.light
        ? const ColorScheme.light(
            primary: Color(0xFF00796B),
            primaryContainer: Color(0xFF4DB6AC),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF455A64),
            secondaryContainer: Color(0xFFCFD8DC),
            surface: Color(0xFFF5F7F8),
            surfaceContainerLowest: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFF4DB6AC),
            primaryContainer: Color(0xFF00796B),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF90A4AE),
            secondaryContainer: Color(0xFF37474F),
            surface: Color(0xFF121212),
            surfaceContainerLowest: Color(0xFF1E1E1E),
          );
  }

  // Midnight Charcoal - elegant, sophisticated, premium
  static ColorScheme _midnightCharcoal(Brightness brightness) {
    return brightness == Brightness.light
        ? const ColorScheme.light(
            primary: Color(0xFF37474F),
            primaryContainer: Color(0xFF546E7A),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF757575),
            secondaryContainer: Color(0xFFE0E0E0),
            surface: Color(0xFFFAFAFA),
            surfaceContainerLowest: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFF546E7A),
            primaryContainer: Color(0xFF37474F),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFFBDBDBD),
            secondaryContainer: Color(0xFF263238),
            surface: Color(0xFF121212),
            surfaceContainerLowest: Color(0xFF1A1A1A),
          );
  }

  // Forest Green - natural, calming, organic
  static ColorScheme _forestGreen(Brightness brightness) {
    return brightness == Brightness.light
        ? const ColorScheme.light(
            primary: Color(0xFF2E7D32),
            primaryContainer: Color(0xFF81C784),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF558B2F),
            secondaryContainer: Color(0xFFA5D6A7),
            surface: Color(0xFFF1F8E9),
            surfaceContainerLowest: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFF81C784),
            primaryContainer: Color(0xFF2E7D32),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFFA5D6A7),
            secondaryContainer: Color(0xFF1B5E20),
            surface: Color(0xFF121212),
            surfaceContainerLowest: Color(0xFF1E1E1E),
          );
  }

  // Royal Purple - premium, luxurious, distinctive
  static ColorScheme _royalPurple(Brightness brightness) {
    return brightness == Brightness.light
        ? const ColorScheme.light(
            primary: Color(0xFF6A1B9A),
            primaryContainer: Color(0xFFBA68C8),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFF7B1FA2),
            secondaryContainer: Color(0xFFE1BEE7),
            surface: Color(0xFFF3E5F5),
            surfaceContainerLowest: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFFBA68C8),
            primaryContainer: Color(0xFF6A1B9A),
            onPrimaryContainer: Colors.white,
            secondary: Color(0xFFCE93D8),
            secondaryContainer: Color(0xFF4A148C),
            surface: Color(0xFF121212),
            surfaceContainerLowest: Color(0xFF1E1E1E),
          );
  }
}