import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// The assigned-driver card from the GoRide tracking sheet (frames `30439:403`
/// and `30431:30716`): driver avatar with an operator-colour status dot, the
/// driver's name, a star rating, and two circular brand-outline actions to
/// message and call. Vehicle make/colour and the plate are surfaced separately
/// in the sheet's vehicle line, so this row stays focused on the person.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.name,
    required this.rating,
    required this.colorValue,
    this.phone,
    this.imageUrl,
    this.onMessage,
    this.onCall,
  });

  /// Driver's display name.
  final String name;

  /// Star rating, e.g. `4.8`.
  final double rating;

  /// Operator-assigned driver colour (ARGB int) shown as a status dot.
  final int colorValue;

  /// Optional phone number shown under the name when present.
  final String? phone;

  /// Optional avatar image URL; falls back to initials.
  final String? imageUrl;

  /// Tapped on the message action.
  final VoidCallback? onMessage;

  /// Tapped on the call action.
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _AvatarWithDot(name: name, imageUrl: imageUrl, colorValue: colorValue),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    rating.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium,
                  ),
                  if (phone != null) ...[
                    Text(
                      '  ·  ',
                      style: theme.textTheme.bodySmall,
                    ),
                    Flexible(
                      child: Text(
                        phone!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleAction(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: onMessage,
          tooltip: 'Message driver',
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleAction(
          icon: Icons.phone_outlined,
          onTap: onCall,
          tooltip: 'Call driver',
        ),
      ],
    );
  }
}

class _AvatarWithDot extends StatelessWidget {
  const _AvatarWithDot({
    required this.name,
    required this.imageUrl,
    required this.colorValue,
  });

  final String name;
  final String? imageUrl;
  final int colorValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        AppAvatar(name: name, imageUrl: imageUrl, size: 52),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(colorValue),
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A circular brand-outline icon button — the green call/message pair in the
/// kit, recoloured to Red Taxi brand red per the theme.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? AppColors.brand
        : Theme.of(context).colorScheme.outline;
    final button = Material(
      color: AppColors.brand.withValues(alpha: enabled ? 0.10 : 0.04),
      shape: CircleBorder(
        side: BorderSide(color: color, width: AppStroke.thin + 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
