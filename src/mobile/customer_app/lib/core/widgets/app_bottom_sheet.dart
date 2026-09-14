import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Shows a themed, rounded-top modal bottom sheet with a drag handle and
/// safe-area padding. Returns the value passed to `Navigator.pop` from [child].
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) {
      return Padding(
        // Lift the sheet above the soft keyboard so input fields stay visible.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DragHandle(color: scheme.outline),
                const SizedBox(height: AppSpacing.md),
                // Scroll when content exceeds the available sheet height
                // (short screens / large font scale) instead of overflowing.
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A title row with a trailing close button, for use at the top of a sheet
/// shown via [showAppBottomSheet].
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.onClose,
  });

  /// Sheet title text.
  final String title;

  /// Close handler. Defaults to popping the current route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
