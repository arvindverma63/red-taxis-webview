import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Semantic colour mapping for a [StatusChip].
enum StatusKind {
  /// Awaiting action — warning tone.
  pending,

  /// In progress — info tone.
  active,

  /// Completed successfully — success tone.
  success,

  /// Failed / cancelled — error tone.
  danger,

  /// No emphasis — neutral tone.
  neutral,
}

/// A small tinted pill that communicates a booking (or generic) status with a
/// semantic colour: tinted background plus matching coloured text.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.kind = StatusKind.neutral,
  });

  /// Status text shown inside the pill.
  final String label;

  /// Semantic colour bucket — see [StatusKind].
  final StatusKind kind;

  Color get _color => switch (kind) {
        StatusKind.pending => AppColors.warning,
        StatusKind.active => AppColors.info,
        StatusKind.success => AppColors.success,
        StatusKind.danger => AppColors.error,
        StatusKind.neutral => AppColors.neutral400,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
    );
  }
}
