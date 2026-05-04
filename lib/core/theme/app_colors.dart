import 'package:flutter/material.dart';

/// App color palette following "The Tactile Concierge" design system
/// from Stitch design project 18398418395735359370
class AppColors {
  AppColors._();

  // Primary Colors (Solar Orange)
  static const Color primary = Color(0xFF904D00);
  static const Color primaryContainer = Color(0xFFFF8C00);
  static const Color primaryFixed = Color(0xFFFFDCC3);
  static const Color primaryFixedDim = Color(0xFFFFB77D);

  // On Primary
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF623200);
  static const Color onPrimaryFixed = Color(0xFF2F1500);
  static const Color onPrimaryFixedVariant = Color(0xFF6E3900);

  // Secondary Colors (Charcoal)
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color secondaryContainer = Color(0xFFE4E2E1);
  static const Color secondaryFixed = Color(0xFFE4E2E1);
  static const Color secondaryFixedDim = Color(0xFFC8C6C6);

  // On Secondary
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF656464);
  static const Color onSecondaryFixed = Color(0xFF1B1C1C);
  static const Color onSecondaryFixedVariant = Color(0xFF474747);

  // Tertiary Colors
  static const Color tertiary = Color(0xFF715B37);
  static const Color tertiaryContainer = Color(0xFFC1A67C);

  // On Tertiary
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF4F3B1A);
  static const Color onTertiaryFixed = Color(0xFF281900);
  static const Color onTertiaryFixedVariant = Color(0xFF584322);

  // Surface Colors
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceBright = Color(0xFFF9F9F9);
  static const Color surfaceContainer = Color(0xFFEEEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E2);
  static const Color surfaceContainerLow = Color(0xFFF3F3F3);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFDADADA);
  static const Color surfaceTint = Color(0xFF904D00);
  static const Color surfaceVariant = Color(0xFFE2E2E2);

  // On Surface
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF564334);

  // Background
  static const Color background = Color(0xFFF9F9F9);
  static const Color onBackground = Color(0xFF1A1C1C);

  // Error Colors
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Outline & Borders
  static const Color outline = Color(0xFF897362);
  static const Color outlineVariant = Color(0xFFDDc1AE);

  // Inverse Colors
  static const Color inverseSurface = Color(0xFF2F3131);
  static const Color inverseOnSurface = Color(0xFFF1F1F1);
  static const Color inversePrimary = Color(0xFFFFB77D);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color ongoing = Color(0xFF2196F3);

  // Gradient for Primary CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Mode Colors - Charcoal surfaces preserving Solar Orange brand
  static const Color darkSurface = Color(0xFF1A1C1C);
  static const Color darkSurfaceBright = Color(0xFF2F3131);
  static const Color darkSurfaceContainer = Color(0xFF252728);
  static const Color darkSurfaceContainerHigh = Color(0xFF353838);
  static const Color darkSurfaceContainerHighest = Color(0xFF3F4141);
  static const Color darkSurfaceContainerLow = Color(0xFF222425);
  static const Color darkSurfaceContainerLowest = Color(0xFF2F3131);
  static const Color darkSurfaceDim = Color(0xFF141516);
  static const Color darkSurfaceVariant = Color(0xFF3F4141);

  // Dark On Surface
  static const Color darkOnSurface = Color(0xFFE2E2E2);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4BE);

  // Dark Background
  static const Color darkBackground = Color(0xFF1A1C1C);
  static const Color darkOnBackground = Color(0xFFE2E2E2);

  // Dark Inverse
  static const Color darkInverseSurface = Color(0xFFE2E2E2);
  static const Color darkInverseOnSurface = Color(0xFF2F3131);
  static const Color darkInversePrimary = Color(0xFFCC7000);

  // Dark Outline
  static const Color darkOutline = Color(0xFF8A8480);
  static const Color darkOutlineVariant = Color(0xFF443F3A);
}
