import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// The GoRide "Set pickup location" bottom card (frame 30439:395): a rounded
/// top sheet pinned over the map, holding a single resolved-address row (pin +
/// title/subtitle + an edit affordance) and a full-width primary CTA.
///
/// Used by the map-pin pickup flow. The address shown reflects whatever the
/// map's centre pin currently resolves to. Theme-only. Feature-local.
class MapPinConfirmCard extends StatelessWidget {
  const MapPinConfirmCard({
    super.key,
    required this.title,
    required this.addressTitle,
    this.addressSubtitle,
    required this.actionLabel,
    required this.onAction,
    this.onEdit,
    this.isLoading = false,
  });

  /// Sheet heading (e.g. "Set pickup location").
  final String title;

  /// Resolved place name on the address row.
  final String addressTitle;

  /// Optional full address line under the name.
  final String? addressSubtitle;

  /// Primary CTA label (e.g. "Next").
  final String actionLabel;

  /// Primary CTA callback.
  final VoidCallback? onAction;

  /// Optional edit (pencil) callback for the address row.
  final VoidCallback? onEdit;

  /// Shows a spinner on the CTA while resolving / submitting.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),

              // Resolved-address row.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: scheme.outline, width: AppStroke.thin),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_outlined,
                          size: 20, color: scheme.onSurface),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            addressTitle,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (addressSubtitle != null &&
                              addressSubtitle!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              addressSubtitle!,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined,
                            size: 20, color: scheme.onSurface),
                        tooltip: 'Edit address',
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel,
                onPressed: onAction,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
