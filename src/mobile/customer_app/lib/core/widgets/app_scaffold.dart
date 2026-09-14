import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Standard page chrome: a consistent [AppBar], a horizontally-padded body and
/// an optional bottom bar pinned above the safe area for primary CTAs.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.bottomBar,
    this.padded = true,
    this.backgroundColor,
  });

  /// AppBar title text.
  final String title;

  /// Page content.
  final Widget body;

  /// Optional AppBar trailing actions.
  final List<Widget>? actions;

  /// Optional custom leading widget (otherwise Flutter supplies a back button).
  final Widget? leading;

  /// Optional CTA bar pinned above the bottom safe area.
  final Widget? bottomBar;

  /// When true (default) the body gets horizontal `AppSpacing.lg` padding.
  final bool padded;

  /// Optional scaffold background override.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final content = padded
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: body,
          )
        : body;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      ),
      body: SafeArea(child: content),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: bottomBar!,
            ),
    );
  }
}
