import 'package:bookly/core/theme/color_schemes.dart';
import 'package:bookly/core/theme/service_color_palette.dart';
import 'package:bookly/core/theme/style_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance < secondLuminance ? firstLuminance : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('service palette contains ten distinct colors', () {
    final values =
        ServiceColorPalette.options.map((option) => option.argbValue).toSet();

    expect(ServiceColorPalette.options, hasLength(10));
    expect(values, hasLength(10));
  });

  test('every service badge color meets normal-text contrast', () {
    for (final option in ServiceColorPalette.options) {
      final contrast = _contrastRatio(option.color, option.onColor);

      expect(
        contrast,
        greaterThanOrEqualTo(4.5),
        reason: '${option.name} must keep badge text readable',
      );
    }
  });

  test('missing and unknown saved colors use the default swatch', () {
    expect(
      ServiceColorPalette.resolve(null).argbValue,
      ServiceColorPalette.defaultValue,
    );
    expect(
      ServiceColorPalette.resolve(0x00000000).argbValue,
      ServiceColorPalette.defaultValue,
    );
  });

  test('nullable resolution distinguishes unsaved and invalid colors', () {
    final saved = ServiceColorPalette.options[5];

    expect(
      ServiceColorPalette.resolveOrNull(saved.argbValue),
      same(saved),
    );
    expect(ServiceColorPalette.resolveOrNull(null), isNull);
    expect(ServiceColorPalette.resolveOrNull(0x00000000), isNull);
  });

  test('theme fallback icon contrast works for every preset and brightness',
      () {
    for (final preset in StylePreset.values) {
      for (final brightness in Brightness.values) {
        final scheme = AppColorSchemes.getColorScheme(preset, brightness);

        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(3),
          reason: '$preset $brightness service icon fallback must be visible',
        );
      }
    }
  });
}
