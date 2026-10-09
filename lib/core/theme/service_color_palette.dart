import 'package:flutter/material.dart';

/// A stable, domain-level palette used to distinguish service types.
///
/// These colors intentionally remain invariant across institution presets so
/// the same service keeps its visual identity in light and dark mode. Each
/// swatch has at least 4.5:1 contrast with white for readable badge labels.
class ServiceColorPalette {
  const ServiceColorPalette._();

  static const options = <ServiceColorOption>[
    ServiceColorOption('Crimson', Color(0xFFB3261E)),
    ServiceColorOption('Burnt orange', Color(0xFF9C4A00)),
    ServiceColorOption('Ochre', Color(0xFF735C00)),
    ServiceColorOption('Forest', Color(0xFF2E7D32)),
    ServiceColorOption('Teal', Color(0xFF00695C)),
    ServiceColorOption('Ocean', Color(0xFF1565C0)),
    ServiceColorOption('Indigo', Color(0xFF3949AB)),
    ServiceColorOption('Purple', Color(0xFF6A1B9A)),
    ServiceColorOption('Rose', Color(0xFFAD1457)),
    ServiceColorOption('Slate', Color(0xFF455A64)),
  ];

  static int get defaultValue => options.first.argbValue;

  static ServiceColorOption resolve(int? argbValue) {
    return resolveOrNull(argbValue) ?? options.first;
  }

  /// Returns the saved palette option, or null when no valid color was saved.
  ///
  /// Screens can use this to fall back to their active semantic theme color
  /// instead of assigning the palette's historical default.
  static ServiceColorOption? resolveOrNull(int? argbValue) {
    if (argbValue == null) return null;

    for (final option in options) {
      if (option.argbValue == argbValue) return option;
    }
    return null;
  }

  /// Returns black or white with the stronger contrast against [background].
  static Color readableForeground(Color background) {
    return background.computeLuminance() > 0.179
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }
}

class ServiceColorOption {
  const ServiceColorOption(this.name, this.color);

  final String name;
  final Color color;

  int get argbValue => color.toARGB32();

  // White is intentionally invariant and contrast-checked against all ten
  // curated domain colors; it does not participate in institution theming.
  Color get onColor => ServiceColorPalette.readableForeground(color);
}
