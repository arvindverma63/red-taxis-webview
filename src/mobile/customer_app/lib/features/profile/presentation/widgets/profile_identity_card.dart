import 'package:flutter/material.dart';

import '../../../../core/domain/auth_user.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// The Account screen's top card, faithful to the GoRide "Account" frame:
///
///  ┌───────────────────────────────────────────┐
///  │  (avatar)  Name                        ›    │  ← identity row, tappable
///  │            ☏ phone                          │
///  │ ───────────────────────────────────────────│  ← divider
///  │  (wallet)  £balance            [ Top Up ]   │  ← wallet row
///  │            Available balance                 │
///  └───────────────────────────────────────────┘
///
/// Built from the shared [AppCard] + [AppAvatar] so styling stays theme-driven;
/// the wallet row is optional (hidden until the wallet feature ships) so the
/// card degrades to a clean identity-only card without it.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.user,
    this.onTapIdentity,
    this.balanceLabel,
    this.onTopUp,
  });

  /// Signed-in customer (null → guest fallback copy).
  final AuthUser? user;

  /// Tap target for the identity row (edit profile). Renders a chevron when set.
  final VoidCallback? onTapIdentity;

  /// Formatted available-balance string (e.g. "£0.00"). When null the wallet
  /// row is omitted entirely.
  final String? balanceLabel;

  /// Top-up callback for the wallet row's pill button.
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (user?.fullName.isNotEmpty ?? false) ? user!.fullName : 'Guest';
    // GoRide shows the phone under the name; fall back to email, then a prompt.
    // The icon follows whichever field is shown (phone vs email) — the restore
    // and login paths populate these differently, so derive both together.
    final secondary = _secondaryLine(user);
    final secondaryIcon = _secondaryIcon(user);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IdentityRow(
            name: name,
            secondary: secondary,
            secondaryIcon: secondaryIcon,
            user: user,
            theme: theme,
            onTap: onTapIdentity,
          ),
          if (balanceLabel != null) ...[
            const Divider(),
            _WalletRow(
              balanceLabel: balanceLabel!,
              onTopUp: onTopUp,
            ),
          ],
        ],
      ),
    );
  }

  String? _secondaryLine(AuthUser? user) {
    final phone = user?.phoneNumber;
    if (phone != null && phone.isNotEmpty) return phone;
    final email = user?.email;
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  /// Icon for the secondary line — must match [_secondaryLine]'s field so a
  /// phone shows a phone glyph and an email shows a mail glyph.
  IconData _secondaryIcon(AuthUser? user) {
    final phone = user?.phoneNumber;
    if (phone != null && phone.isNotEmpty) return Icons.phone_outlined;
    return Icons.mail_outline;
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.name,
    required this.secondary,
    required this.secondaryIcon,
    required this.user,
    required this.theme,
    required this.onTap,
  });

  final String name;
  final String? secondary;
  final IconData secondaryIcon;
  final AuthUser? user;
  final ThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = theme.textTheme.bodySmall?.color;

    final content = Row(
      children: [
        AppAvatar(name: name, imageUrl: null, size: 52),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondary != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(secondaryIcon, size: 14, color: secondaryColor),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        secondary!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right, size: 22, color: secondaryColor),
        ],
      ],
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.balanceLabel, required this.onTopUp});

  final String balanceLabel;
  final VoidCallback? onTopUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        // Wallet glyph in a soft brand-tinted rounded square (GoRide uses a
        // tinted card-icon here, distinct from the flat menu glyphs below).
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.account_balance_wallet_outlined,
              size: 22, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                balanceLabel,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text('Available balance', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Compact pill outline button — GoRide's "Top Up" affordance.
        OutlinedButton(
          onPressed: onTopUp,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            side: BorderSide(color: scheme.outline, width: AppStroke.thin),
            shape: const StadiumBorder(),
            textStyle: theme.textTheme.labelMedium,
            foregroundColor: theme.textTheme.titleMedium?.color,
          ),
          child: const Text('Top Up'),
        ),
      ],
    );
  }
}
