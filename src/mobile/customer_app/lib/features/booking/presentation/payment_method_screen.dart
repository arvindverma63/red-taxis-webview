import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../payment/presentation/payment_routes.dart';
import '../application/booking_draft_controller.dart';
import '../application/quote_controller.dart';
import '../data/booking_repository.dart';
import 'widgets/widgets.dart';

/// One selectable payment option. [iconBackground]/[iconColor] carry the brand
/// mark colours for each method (data colours — the theme-only exception).
class _PaymentOption {
  const _PaymentOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.iconBackground,
    this.iconColor,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color? iconBackground;
  final Color? iconColor;
}

const _publicOptions = [
  _PaymentOption(
    id: 'cash',
    label: 'Cash',
    subtitle: 'Pay the driver directly',
    icon: Icons.attach_money,
    iconBackground: Color(0x1F12B76A), // success tint
    iconColor: AppColors.success,
  ),
  _PaymentOption(
    id: 'card',
    label: 'Card',
    subtitle: 'Pay by card in the vehicle',
    icon: Icons.credit_card,
    iconBackground: Color(0x1F2E90FA), // info tint
    iconColor: AppColors.info,
  ),
  _PaymentOption(
    id: 'applePay',
    label: 'Apple Pay',
    subtitle: 'Pay with Apple Pay',
    icon: Icons.phone_iphone,
    iconBackground: Color(0x14000000),
    iconColor: AppColors.neutral900,
  ),
];

const _accountOption = _PaymentOption(
  id: 'account',
  label: 'Bill to account',
  subtitle: 'Charge your business account',
  icon: Icons.business_center_outlined,
);

/// Choose how to pay, then submit the booking request. Styled to GoRide frame
/// 30439:399: bordered selectable rows with branded icon tiles and a brand
/// check on the active row, plus a full-width "OK" CTA.
///
/// Account users also see a "Bill to account" option. Confirming calls
/// `createRequest`; success routes to the confirmation screen — wiring
/// unchanged.
class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  bool _submitting = false;

  Future<void> _confirm() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _submitting = true);
    try {
      // Read the draft fresh on every attempt. It lives in a NotifierProvider
      // for the whole flow and is NEVER reset on failure, so a retry re-submits
      // the user's identical details (pickup, destination, passengers, time,
      // payment) with no data loss.
      final draft = ref.read(bookingDraftProvider);
      final repo = ref.read(bookingRepositoryProvider);
      final user = ref.read(currentUserProvider);

      final body = <String, dynamic>{
        'pickup': {
          'description': draft.pickup?.description,
          'postcode': draft.pickup?.postcode,
          'lat': draft.pickup?.lat,
          'lng': draft.pickup?.lng,
        },
        'destination': {
          'description': draft.dropoff?.description,
          'postcode': draft.dropoff?.postcode,
          'lat': draft.dropoff?.lat,
          'lng': draft.dropoff?.lng,
        },
        'vias': draft.vias
            .map((p) => {
                  'description': p.description,
                  'postcode': p.postcode,
                  'lat': p.lat,
                  'lng': p.lng,
                })
            .toList(),
        'vehicleId': draft.vehicleId,
        'passengers': draft.passengers,
        'scheduledFor': draft.scheduledFor?.toUtc().toIso8601String(),
        'asap': draft.isAsap,
        'paymentMethod': draft.paymentMethod,
        'accountNo': draft.paymentMethod == 'account'
            ? user?.username
            : kCashAccountNo,
        'quote': draft.quote == null
            ? null
            : {
                'priceCash': draft.quote!.priceCash,
                'priceAccount': draft.quote!.priceAccount,
              },
      };

      final result = await repo.createRequest(body);
      if (!mounted) return;

      // Pre-pay at booking for card / Apple Pay (PRD §10). Cash + account skip
      // checkout. If payment isn't completed the request still stands (operator
      // accept model) — surface it and let the customer settle from Activity.
      final method = draft.paymentMethod;
      if (method == 'card' || method == 'applePay') {
        final amount = draft.quote?.priceCash ?? 0;
        final paid = await context.push<bool>(
          paymentCheckoutPath,
          extra: PaymentCheckoutArgs(
            bookingRef: result.requestId,
            amount: amount,
            method: method == 'applePay'
                ? PaymentMethodKind.applePay
                : PaymentMethodKind.card,
          ),
        );
        if (!mounted) return;
        if (paid != true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment not completed — you can pay from your bookings.'),
            ),
          );
        }
      }

      router.go(Routes.bookingConfirm, extra: result.requestId);
    } catch (e) {
      if (!mounted) return;
      // Connection/server failure: offer an explicit Retry without losing any
      // entered details. A validation error (e.g. bad address) is not
      // retryable as-is, so it just surfaces the message.
      if (_isNetworkError(e)) {
        final retry = await showConfirmDialog(
          context,
          title: "Couldn't send your booking",
          message:
              'We could not reach the office. Your booking details are saved — '
              'check your connection and try again.',
          confirmLabel: 'Retry',
          cancelLabel: 'Not now',
        );
        if (retry && mounted) {
          await _confirm();
          return;
        }
      } else {
        messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// True when [e] is a connection/timeout failure (no HTTP status) rather than
  /// a server validation error. [ApiException.isNetwork] is set by the dio
  /// client when there is no response.
  bool _isNetworkError(Object e) => e is ApiException && e.isNetwork;

  String _errorText(Object e) {
    if (e is ApiException) return e.message;
    final msg = e.toString();
    return msg.isEmpty
        ? "Couldn't send your booking. Please try again."
        : msg.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final user = ref.watch(currentUserProvider);
    final isAccountUser = user?.isAccount ?? false;

    final options = [
      ..._publicOptions,
      if (isAccountUser) _accountOption,
    ];

    return AppScaffold(
      title: 'Choose Payment Method',
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final option = options[i];
          return PaymentMethodRow(
            label: option.label,
            subtitle: option.subtitle,
            icon: option.icon,
            iconBackground: option.iconBackground,
            iconColor: option.iconColor,
            selected: draft.paymentMethod == option.id,
            onTap: _submitting
                ? null
                : () => ref
                    .read(bookingDraftProvider.notifier)
                    .setPaymentMethod(option.id),
          );
        },
      ),
      bottomBar: AppButton(
        label: 'OK',
        onPressed: _submitting ? null : _confirm,
        isLoading: _submitting,
      ),
    );
  }
}
