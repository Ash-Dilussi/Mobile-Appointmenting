import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/style_preset_provider.dart';
import 'core/router/app_router.dart';

/// Main application widget
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final preset = ref.watch(stylePresetProvider);

    return MaterialApp.router(
      title: 'In-Call Appointment Handler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromPreset(preset, Brightness.light),
      darkTheme: AppTheme.fromPreset(preset, Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
