import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The GoRide "Where do you want to go?" grouped card (frames 30439:393/394):
/// a soft-filled card holding a "current location" pickup row, a divider, then
/// a destination input with a trailing "+" add-stop circle button.
///
/// The destination input is a real, focusable [TextField] so the typing state
/// (30439:394) works. The current-location row is a tappable summary (tap to
/// edit pickup). Pins are *data* colours: pickup/origin green
/// ([AppColors.success]), destination red ([AppColors.brand]) — a deliberate
/// at-a-glance origin↔destination cue (Peter-confirmed 2026-06-15, keep green).
///
/// Feature-local — flag for promotion if reused outside booking.
class LocationSearchCard extends StatelessWidget {
  const LocationSearchCard({
    super.key,
    required this.pickupLabel,
    required this.destinationController,
    this.destinationHint = 'Where to?',
    this.destinationFocusNode,
    this.onDestinationChanged,
    this.onPickupTap,
    this.onAddStop,
    this.autofocusDestination = true,
  });

  /// Text shown on the current-location / pickup row.
  final String pickupLabel;

  /// Controller for the destination input.
  final TextEditingController destinationController;

  /// Placeholder for the destination input.
  final String destinationHint;

  /// Optional focus node so the parent can drive focus.
  final FocusNode? destinationFocusNode;

  /// Destination text-change callback (drives debounced search).
  final ValueChanged<String>? onDestinationChanged;

  /// Tap on the current-location row (switch to pickup edit).
  final VoidCallback? onPickupTap;

  /// Tap on the "+" add-stop button. When null the button is hidden.
  final VoidCallback? onAddStop;

  /// Autofocus the destination input when the card mounts.
  final bool autofocusDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline, width: AppStroke.thin),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Current location / pickup row ──────────────────────────────
          _SoftRow(
            onTap: onPickupTap,
            child: Row(
              children: [
                const _Pin(color: AppColors.success),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    pickupLabel,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),

          // ── Destination input + add-stop button ────────────────────────
          Row(
            children: [
              Expanded(
                child: _SoftRow(
                  child: Row(
                    children: [
                      const _Pin(color: AppColors.brand),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: destinationController,
                          focusNode: destinationFocusNode,
                          autofocus: autofocusDestination,
                          onChanged: onDestinationChanged,
                          textInputAction: TextInputAction.search,
                          style: theme.textTheme.bodyLarge,
                          // Caret inherits the brand red from textSelectionTheme.
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: destinationHint,
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onAddStop != null) ...[
                const SizedBox(width: AppSpacing.md),
                _AddStopButton(onTap: onAddStop!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A soft-filled, rounded inner row (the GoRide field background).
class _SoftRow extends StatelessWidget {
  const _SoftRow({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: content,
    );
  }
}

/// A small solid location pin glyph in a data colour.
class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, size: 22, color: color);
  }
}

/// The hollow brand-ringed "+" add-stop circle.
class _AddStopButton extends StatelessWidget {
  const _AddStopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.4),
          width: AppStroke.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add, color: scheme.primary, size: 22),
        ),
      ),
    );
  }
}
