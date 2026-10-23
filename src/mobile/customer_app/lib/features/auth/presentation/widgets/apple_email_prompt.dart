import 'package:flutter/material.dart';

import '../auth_validators.dart';

/// Asks for an email when Apple did not share one. Returns null if dismissed.
Future<String?> promptForAppleEmail(BuildContext context) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add your email'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apple did not share an email address. Enter one to finish '
              'creating your account.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'you@example.com'),
              validator: AuthValidators.email,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
