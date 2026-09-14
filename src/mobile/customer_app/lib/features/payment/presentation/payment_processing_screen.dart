import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../application/payment_controller.dart';
import '../domain/payment.dart';

/// Local UI phase of the simulated checkout. Distinct from the controller's
/// `AsyncValue` so we can show a dedicated success/fail screen, not just a
/// spinner-over-form.
enum _Phase { ready, processing, success, failure }

/// Pre-pay checkout shown when a customer chooses card / Apple Pay at booking.
///
/// Shows the amount + selected method, a single "Pay {amount}" CTA that runs
/// the simulated Revolut / Apple Pay sheet, then a processing spinner and a
/// success (tick) or failure (retry) state. On success it pops with `true` so
/// the booking flow can submit the request as pre-paid.
///
/// It is intentionally and visibly a simulation — a "Demo checkout" note sits
/// under the CTA until the Revolut wiring (B9/B10) lands.
class PaymentProcessingScreen extends ConsumerStatefulWidget {
  const PaymentProcessingScreen({
    super.key,
    required this.bookingRef,
    required this.amount,
    this.method = PaymentMethodKind.card,
  });

  /// Booking the order is created against (B9 path param).
  final String bookingRef;

  /// Amount to charge, in GBP.
  final double amount;

  /// The card-type method chosen on the payment-method screen.
  final PaymentMethodKind method;

  @override
  ConsumerState<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState
    extends ConsumerState<PaymentProcessingScreen> {
  _Phase _phase = _Phase.ready;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _phase = _Phase.processing;
      _error = null;
    });
    try {
      await ref.read(paymentControllerProvider.notifier).pay(
            bookingRef: widget.bookingRef,
            amount: widget.amount,
            method: widget.method,
          );
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failure;
        _error = e is PaymentFailure ? e.message : e.toString();
      });
    }
  }

  void _done() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Payment',
      // Block accidental dismissal mid-charge.
      leading: _phase == _Phase.processing ? const SizedBox.shrink() : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: switch (_phase) {
            _Phase.ready => _ReadyView(
                amount: widget.amount,
                method: widget.method,
                onPay: _pay,
              ),
            _Phase.processing => _ProcessingView(method: widget.method),
            _Phase.success => _SuccessView(
                amount: widget.amount,
                onDone: _done,
              ),
            _Phase.failure => _FailureView(
                message: _error ?? 'Payment could not be completed.',
                onRetry: _pay,
                onCancel: () => Navigator.of(context).pop(false),
              ),
          },
        ),
      ),
    );
  }
}

/// Pre-charge summary + the primary "Pay" CTA.
class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.amount,
    required this.method,
    required this.onPay,
  });

  final double amount;
  final PaymentMethodKind method;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCard(
          child: Column(
            children: [
              Text('Amount due', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Fmt.money(amount),
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(method.icon, size: 20, color: AppColors.neutral500),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text('Paying with ${method.label}',
                        style: theme.textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Pay ${Fmt.money(amount)}',
          icon: method.icon,
          onPressed: onPay,
        ),
        const SizedBox(height: AppSpacing.md),
        _DemoNote(),
      ],
    );
  }
}

/// Spinner shown while the simulated sheet authorises + the status polls.
class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.method});

  final PaymentMethodKind method;

  @override
  Widget build(BuildContext context) {
    return LoadingView(message: 'Confirming ${method.label} payment…');
  }
}

/// Success state — tick + confirmation, pops `true` on continue.
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.amount, required this.onDone});

  final double amount;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 72, color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        Text('Payment received', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${Fmt.money(amount)} paid. Your booking request will be sent for confirmation.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Continue', onPressed: onDone),
        const SizedBox(height: AppSpacing.md),
        _DemoNote(),
      ],
    );
  }
}

/// Failure state — reuses [ErrorView] for the message/retry, plus a cancel.
class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ErrorView(
          message: message,
          onRetry: onRetry,
          retryLabel: 'Try again',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Choose another method',
          variant: AppButtonVariant.text,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

/// The "this is a placeholder" banner — kept until Revolut is wired (B9/B10).
class _DemoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Demo checkout — Revolut wiring pending',
      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.neutral400),
      textAlign: TextAlign.center,
    );
  }
}
