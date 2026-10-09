import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/core/theme/style_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('theme typography follows active brightness and preset',
      (tester) async {
    Future<Color?> pumpText(StylePreset preset, Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.fromPreset(preset, brightness),
          darkTheme: AppTheme.fromPreset(preset, brightness),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          home: const Scaffold(body: Text('Theme-aware text')),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Theme-aware text'));
      return Theme.of(context).textTheme.bodyMedium?.color;
    }

    final lightColor = await pumpText(
      StylePreset.solarOrange,
      Brightness.light,
    );
    final darkColor = await pumpText(
      StylePreset.royalPurple,
      Brightness.dark,
    );

    expect(lightColor, AppTheme.lightTheme.colorScheme.onSurface);
    expect(
      darkColor,
      AppTheme.fromPreset(
        StylePreset.royalPurple,
        Brightness.dark,
      ).colorScheme.onSurface,
    );
    expect(darkColor, isNot(lightColor));
  });
}
