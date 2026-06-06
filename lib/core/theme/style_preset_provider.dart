import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'style_preset.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';

/// Provider that exposes the active StylePreset from the current institution.
/// Falls back to solarOrange if no institution or themePreset is set.
final stylePresetProvider = Provider<StylePreset>((ref) {
  final institution = ref.watch(currentInstitutionProvider);
  if (institution == null || institution.themePreset.isEmpty) {
    return StylePreset.solarOrange;
  }
  return StylePreset.values.firstWhere(
    (p) => p.name == institution.themePreset,
    orElse: () => StylePreset.solarOrange,
  );
});