import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/notifications_controller.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/profile_identity_card.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_row.dart';

/// Account tab root, faithful to the GoRide "Account" frame. Wired by the app
/// shell as the `/profile` tab body — NOT a pushed route, so it has no back
/// button. Shows the centred "Account" header (brand mark + overflow), the
/// identity + wallet card, the grouped settings menu and a red Logout row.
///
/// All wiring is preserved: sub-page navigation, the unread-notifications
/// badge, and sign-out (confirm dialog → [SessionController.signOut]).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isGuest = user == null;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Account'),
        // Brand mark in place of GoRide's logo (no asset shipped yet) — themed
        // so a real logo swaps in here later without touching layout.
        leading: Center(
          child: Icon(Icons.local_taxi, color: scheme.primary, size: 28),
        ),
        actions: [
          // The overflow only offers Settings + Logout, both of which require a
          // signed-in user; hide it for guests (they get the sign-in prompt).
          if (!isGuest)
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onPressed: () => _showMore(context, ref),
            ),
        ],
      ),
      // Guests reach this tab without authenticating (other tabs redirect to
      // Sign in). Show a sign-in prompt rather than the authenticated menu +
      // Logout, which would act on no session.
      body: isGuest
          ? _GuestPrompt(onSignIn: () => context.go(Routes.signIn))
          : SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            ProfileIdentityCard(
              user: user,
              onTapIdentity: () => _editProfile(context),
              // Wallet/top-up isn't a built feature yet; omit the balance row
              // until it ships rather than show a fake balance. The card
              // degrades gracefully to identity-only.
              balanceLabel: null,
            ),
            const SizedBox(height: AppSpacing.xl),
            SettingsGroupCard(
              children: [
                SettingsRow(
                  icon: Icons.location_on_outlined,
                  label: 'Saved addresses',
                  onTap: () => context.push(Routes.savedAddresses),
                ),
                SettingsRow(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  trailing: unread > 0 ? _CountBadge(count: unread) : null,
                  onTap: () => context.push(Routes.notifications),
                ),
                SettingsRow(
                  icon: Icons.credit_card,
                  label: 'Payment methods',
                  onTap: () => context.push(Routes.paymentMethods),
                ),
                SettingsRow(
                  icon: Icons.tune,
                  label: 'Settings',
                  onTap: () => context.push(Routes.settings),
                ),
                SettingsRow(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => _comingSoon(context, 'Help & Support'),
                ),
                SettingsRow(
                  icon: Icons.star_border,
                  label: 'Rate us',
                  onTap: () => _comingSoon(context, 'Rate us'),
                ),
                SettingsRow(
                  icon: Icons.logout,
                  label: 'Logout',
                  destructive: true,
                  trailing: const SizedBox.shrink(),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    // Profile editing isn't a built sub-page yet; settings is the closest
    // existing destination. Surface a hint rather than dead-tap.
    _comingSoon(context, 'Edit profile');
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon.')),
    );
  }

  Future<void> _showMore(BuildContext context, WidgetRef ref) async {
    // GoRide's header overflow; offer the sign-out action here too.
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Settings'),
              onTap: () => Navigator.of(sheetContext).pop('settings'),
            ),
            ListTile(
              leading: Icon(Icons.logout,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: Text(
                'Logout',
                style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop('logout'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'settings':
        context.push(Routes.settings);
      case 'logout':
        await _signOut(context, ref);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
          const SnackBar(content: Text('Could not sign out. Please try again.')),
        );
      }
    }
  }
}

/// Sign-in prompt shown on the Account tab for guests (no session). Mirrors the
/// app's empty-state language ([EmptyView] + [AppButton]) so a guest gets a
/// clear call to action instead of the authenticated menu and Logout.
class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(
              icon: Icons.account_circle_outlined,
              title: 'Sign in to your account',
              subtitle: 'Sign in to manage your saved addresses, payment '
                  'methods and notifications.',
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Sign in',
              icon: Icons.login,
              fullWidth: false,
              onPressed: onSignIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small brand pill showing the unread-notifications count, with a trailing
/// chevron — the Account row's trailing affordance when there are unread items.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.chevron_right,
          size: 22,
          color: theme.textTheme.bodySmall?.color,
        ),
      ],
    );
  }
}
