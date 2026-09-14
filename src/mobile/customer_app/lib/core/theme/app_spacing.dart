/// Spacing + radius tokens, mirrored from the GoRide design system.
///
/// Spacing values match GoRide `Gap and Padding/Positive/GapPadding-*`.
/// Radii match `Corner Radius/Radius-*` (Button-1000 = full pill).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0; // GapPadding-12
  static const lg = 16.0; // GapPadding-16
  static const xl = 24.0; // GapPadding-24
  static const xxl = 36.0; // GapPadding-36
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pill = 1000.0; // Radius-Button-1000
}

abstract final class AppStroke {
  static const thin = 1.0; // Stroke Line/Stroke-1
}
