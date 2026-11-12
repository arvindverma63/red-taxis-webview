import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/auth_controller.dart';

/// Account actions shared by the Profile screen and the Home drawer.

Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete account?',
    message:
        'This permanently deletes your account and personal data. Your '
        'saved addresses and trip history will be removed and this cannot '
        'be undone.',
    confirmLabel: 'Delete account',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final auth = ref.read(authControllerProvider.notifier);
  var ok = await auth.deleteAccount();
  // Accounts with a password must confirm it; keep asking until it is right
  // or the customer cancels.
  while (!ok && auth.deleteNeedsPassword) {
    if (!context.mounted) return;
    final password = await _askPassword(context);
    if (password == null) return;
    ok = await auth.deleteAccount(password: password);
  }
  if (!context.mounted) return;
  if (ok) {
    context.go(Routes.signIn);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
  } else {
    final err = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err is ApiException
              ? err.message
              : 'Could not delete your account. Please try again.',
        ),
      ),
    );
  }
}

Future<String?> _askPassword(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(hintText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
}

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Logout',
    message: 'You will need to sign in again to book a taxi.',
    confirmLabel: 'Logout',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.go(Routes.signIn);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
    }
  }
}
