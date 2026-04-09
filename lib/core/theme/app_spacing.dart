/// Spacing system following the 4-point grid
/// Spacing Scale 3 from Stitch design
class AppSpacing {
  AppSpacing._();

  // Base spacing values (4-point grid)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Specific spacing for common use cases
  static const double screenPadding = 20.0;
  static const double cardPadding = 16.0;
  static const double sectionSpacing = 24.0;
  static const double itemSpacing = 12.0;
  static const double iconTextSpacing = 8.0;

  // Border radius following "The Polished Pebble" aesthetic
  // Minimum 12px, XL 32px, Full 9999px
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0; // 1.5rem
  static const double radiusLg = 24.0; // 1.5rem for inputs
  static const double radiusXl = 32.0; // 2rem for cards
  static const double radiusFull = 9999.0; // For buttons

  // Button specifications
  static const double buttonMinHeight = 56.0;
  static const double buttonRadius = radiusFull;

  // Card specifications
  static const double cardRadius = radiusXl;
  static const double cardElevation = 0.0; // Tonal layering instead of shadow

  // Input specifications
  static const double inputRadius = radiusMd;
}
