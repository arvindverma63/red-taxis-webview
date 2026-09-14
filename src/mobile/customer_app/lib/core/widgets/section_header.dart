import 'package:flutter/material.dart';

import 'app_button.dart';

/// A section title (titleMedium) with an optional trailing text action, placed
/// above lists and grouped content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  /// Section title text.
  final String title;

  /// Optional trailing action label — renders a text button when set together
  /// with [onAction].
  final String? actionLabel;

  /// Tap callback for the trailing action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null)
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: AppButtonVariant.text,
            fullWidth: false,
          ),
      ],
    );
  }
}
