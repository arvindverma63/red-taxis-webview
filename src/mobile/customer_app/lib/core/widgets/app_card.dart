import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A soft, themed container matching the app's [CardThemeData] — optionally
/// tappable. Use for grouped content: booking summaries, address blocks, etc.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  /// Content of the card.
  final Widget child;

  /// Optional tap callback — when set the card ripples on press.
  final VoidCallback? onTap;

  /// Inner padding around [child]. Defaults to `AppSpacing.lg`.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;
    final radius = BorderRadius.circular(AppRadius.lg);

    final shape = cardTheme.shape ??
        RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.colorScheme.outline, width: AppStroke.thin),
        );

    final content = Padding(padding: padding, child: child);

    return Material(
      color: cardTheme.color ?? theme.colorScheme.surface,
      elevation: cardTheme.elevation ?? 0,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: content,
            ),
    );
  }
}
