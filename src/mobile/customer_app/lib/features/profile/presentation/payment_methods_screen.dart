import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/payment_cards_controller.dart';
import '../domain/payment_card.dart';

/// Lists saved payment methods. Card payments are deferred (cash-only
/// go-live) — until Revolut tokenisation (B9) is wired, real users see a
/// "coming soon" state explaining trips are paid in cash. Any cards present
/// (preview/demo builds, or once B9 lands) are listed with an "Add card"
/// affordance.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(paymentCardsProvider);
    final user = ref.watch(currentUserProvider);
    final isAccount = user?.isAccount ?? false;

    return AppScaffold(
      title: 'Payment methods',
      body: cards.when(
        loading: () => const LoadingView(message: 'Loading cards…'),
        error: (e, _) => ErrorView(
          message: 'Could not load your payment methods.',
          onRetry: () => ref.invalidate(paymentCardsProvider),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            if (isAccount) ...[
              const SectionHeader(title: 'Account billing'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Your trips are billed to your business account — no '
                        'card is needed.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const SectionHeader(title: 'Cards'),
            const SizedBox(height: AppSpacing.sm),
            if (list.isEmpty)
              const EmptyView(
                icon: Icons.payments_outlined,
                title: 'Card payments coming soon',
                subtitle: 'Pay your driver in cash for now. In-app card '
                    'payments are on the way.',
              )
            else
              ...list.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _CardTile(card: c),
                  )),
          ],
        ),
      ),
      // Only offer "Add card" when card management is actually available
      // (cards present in preview/demo, or once B9 ships). Real users in the
      // cash-only go-live see no dead-end button.
      bottomBar: cards.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : AppButton(
                label: 'Add card',
                icon: Icons.add_card,
                onPressed: () => _showAddCardSheet(context),
              ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _showAddCardSheet(BuildContext context) {
    return showAppBottomSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Add card'),
          Icon(
            Icons.lock_outline,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Secure card capture is coming soon. Cards will be tokenised by '
            'Revolut — we never store your full card number.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Got it',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final subtitle = card.last4.isEmpty ? null : '•••• •••• •••• ${card.last4}';
    return AppListTile(
      icon: _brandIcon(card.brand),
      title: card.label,
      subtitle: subtitle,
      trailing: card.isDefault
          ? StatusChip(label: 'Default', kind: StatusKind.active)
          : null,
    );
  }

  IconData _brandIcon(String brand) {
    switch (brand) {
      case 'applePay':
        return Icons.apple;
      case 'visa':
      case 'mastercard':
      default:
        return Icons.credit_card;
    }
  }
}
