import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/social_auth_buttons.dart';

/// Create a public-customer account: full name, email, phone, password.
/// Submits to `POST /api/v2/customer-auth/register-customer` (with a mock fallback while
/// B1 is pending) and replaces the stack with Home on success. The same screen
/// is reused inside the booking flow, so it accepts optional prefilled values
/// and an [onComplete] override for the in-booking variant.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    this.initialFullName,
    this.initialEmail,
    this.initialPhone,
    this.onComplete,
  });

  final String? initialFullName;
  final String? initialEmail;
  final String? initialPhone;

  /// Called after a successful registration instead of the default
  /// `context.go(Routes.home)` — used when embedded in the booking flow.
  final VoidCallback? onComplete;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Gates the Sign up button — the customer must agree to the Terms first.
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.initialFullName);
    _email = TextEditingController(text: widget.initialEmail);
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_agreedToTerms) return;
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).registerCustomer(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _phone.text.trim(),
          password: _password.text,
        );
    if (!ok || !mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      context.go(Routes.home);
    }
  }

  void _comingSoon(String what) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$what is coming soon.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.onSurface,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    return AppScaffold(
      // Empty title → back chevron only, matching the GoRide header layout.
      title: '',
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xl,
            ),
            children: [
              const AuthHeader(
                title: 'Create your account',
                subtitle:
                    "Let's get you booked in. Enter your details to create "
                    'your Ace Taxis account.',
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthErrorBanner(error: state.error),
              AppTextField(
                controller: _fullName,
                label: 'Full name',
                hint: 'Jane Smith',
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                enabled: !loading,
                autofillHints: const [AutofillHints.name],
                validator: AuthValidators.fullName,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !loading,
                autofillHints: const [AutofillHints.email],
                validator: AuthValidators.email,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _phone,
                label: 'Phone number',
                hint: '07000 000000',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                enabled: !loading,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: AuthValidators.phone,
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                enabled: !loading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.password,
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                enabled: !loading,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.confirmPassword(() => _password.text),
              ),
              const SizedBox(height: AppSpacing.lg),
              TermsCheckbox(
                value: _agreedToTerms,
                enabled: !loading,
                onChanged: (v) => setState(() => _agreedToTerms = v),
                onTermsTap: () => _comingSoon('The Terms & Conditions page'),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Sign up',
                isLoading: loading,
                // Disabled until the Terms are agreed.
                onPressed: _agreedToTerms ? _submit : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Already have an account?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => context.push(Routes.signIn),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SocialAuthButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
