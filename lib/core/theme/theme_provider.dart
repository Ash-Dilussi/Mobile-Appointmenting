import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/hive_service.dart';
import '../../main.dart';

/// Provider for the current theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return ThemeModeNotifier(hiveService);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final HiveService _hiveService;

  ThemeModeNotifier(this._hiveService) : super(_parseThemeMode(_hiveService.getThemeMode()));

  static ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _modeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _hiveService.saveThemeMode(_modeToString(mode));
  }
}
