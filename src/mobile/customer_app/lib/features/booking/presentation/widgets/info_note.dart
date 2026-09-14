import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A soft inline note row: a leading icon and a line of copy on a tinted
/// rounded background. Used for non-blocking advisories on the booking flow
/// (out-of-hours expectation, location-off fallback hint).
///
/// Colours follow the passed [colour]; defaults to the theme's info/secondary
/// tone so the note reads as guidance, not an error.
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.icon,
    required this.message,
    this.colour,
  });

  final IconData icon;
  final String message;

  /// Optional accent colour for the icon + tint. Defaults to the theme primary.
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = colour ?? theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accent.withValues(alpha: 0.30),
          width: AppStroke.thin,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Expectation copy shown when a ride is booked outside operating hours. The
/// wording is intentionally generic — we do not assert specific hours unless
/// they are confirmed in [AppConfig] (see its operating-hours docs).
class OutOfHoursNote extends StatelessWidget {
  const OutOfHoursNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoNote(
      icon: Icons.nightlight_outlined,
      // Warning is a semantic data colour (documented theme-only exception) —
      // amber reads as "heads up", not "error".
      colour: AppColors.warning,
      message:
          'This is outside our usual hours. Out-of-hours bookings are confirmed '
          'when the office opens, so it may take a little longer to hear back.',
    );
  }
}

/// Inline hint shown on the pickup step when location access is unavailable, so
/// the user knows to type their pickup address manually rather than waiting for
/// the map to centre on them.
class LocationOffNote extends StatelessWidget {
  const LocationOffNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoNote(
      icon: Icons.location_off_outlined,
      message: 'Location off — enter your pickup address.',
    );
  }
}
