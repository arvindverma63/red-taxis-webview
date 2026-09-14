import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows a themed confirmation dialog and resolves to `true` when the user taps
/// the confirm action, `false`/`null` otherwise. Used for destructive or
/// session-ending actions (sign out, cancel booking, delete address).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // The app-wide TextButton theme foreground is brand red; force a
            // neutral colour on Cancel so the destructive confirm action stays
            // the only red button in the dialog.
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodyMedium?.color,
            ),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
