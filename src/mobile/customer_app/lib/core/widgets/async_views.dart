import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Centred loading indicator with an optional message — for page/list loading.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  /// Optional caption shown beneath the spinner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AdaptiveCenter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Centred error state: icon, message and an optional "Retry" action — for
/// failed page/list loads.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
  });

  /// User-facing error message.
  final String message;

  /// Optional retry callback — renders a button when set.
  final VoidCallback? onRetry;

  /// Leading icon. Defaults to an error outline.
  final IconData icon;

  /// Label for the retry button.
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                fullWidth: false,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centred empty state: icon, title and subtitle — for empty lists/pages.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  /// Headline for the empty state.
  final String title;

  /// Optional supporting copy beneath the title.
  final String? subtitle;

  /// Leading icon. Defaults to an empty-inbox glyph.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurface),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centres [child] within the available space, but adapts so it never overflows
/// on small screens:
/// - **Bounded height** (e.g. inside an `Expanded`, with the keyboard shrinking
///   the viewport): centres when the child fits, and scrolls instead of throwing
///   a RenderFlex overflow when it doesn't.
/// - **Unbounded height** (e.g. inside a `ListView`/`Column`): renders the child
///   directly so it sizes to its content and the parent handles scrolling —
///   wrapping it in a viewport here would throw "unbounded height".
class AdaptiveCenter extends StatelessWidget {
  const AdaptiveCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
