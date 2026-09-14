import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A circular white map-overlay control with a soft shadow, used for the
/// back and recenter affordances that float over the map in the GoRide
/// tracking frame (`30439:403`). Sized and shaped to match the kit's
/// floating map buttons.
class MapFab extends StatelessWidget {
  const MapFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  /// Glyph shown in the centre of the control.
  final IconData icon;

  /// Tap handler.
  final VoidCallback onTap;

  /// Optional accessibility tooltip / semantics label.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: AppColors.neutral900.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: scheme.onSurface),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
