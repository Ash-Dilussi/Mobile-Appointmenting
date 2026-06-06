/// Style presets for institutional branding.
/// Each preset defines a unique color scheme identity.
enum StylePreset {
  solarOrange('Solar Orange', 'Default brand colors'),
  clinicTeal('Clinic Teal', 'Professional healthcare aesthetic'),
  midnightCharcoal('Midnight Charcoal', 'Elegant dark theme'),
  forestGreen('Forest Green', 'Natural, calming vibe'),
  royalPurple('Royal Purple', 'Premium, luxurious feel');

  final String displayName;
  final String description;

  const StylePreset(this.displayName, this.description);
}