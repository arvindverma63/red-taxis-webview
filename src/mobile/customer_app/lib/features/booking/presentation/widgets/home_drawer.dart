import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../guide/presentation/user_guide_sheet.dart';
import '../../../profile/application/notifications_controller.dart';
import '../../../profile/presentation/account_actions.dart';

/// Side menu opened from the Home hamburger: yellow identity header with an
/// Edit Profile pill, the account shortcuts, Delete Account and a Logout bar.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    // The drawer's own context dies as soon as it closes, so grab everything
    // that is needed afterwards (router, messenger, root context) up front.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    void open(String path) {
      Navigator.of(context).pop();
      router.push(path);
    }

    Widget item(IconData icon, String label, VoidCallback onTap,
        {Widget? trailing}) {
      return Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(icon, size: 28, color: AppColors.neutral600),
            title: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: trailing ??
                const Icon(Icons.chevron_right, color: AppColors.neutral600),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      );
    }

    return Drawer(
      width: (width * 0.82).clamp(280, 340),
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.brand,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 8,
              16,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AppAvatar(
                        name: user?.fullName ?? '',
                        imageUrl: user?.photoUrl,
                        size: 60,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Guest',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          if ((user?.phoneNumber ?? '').isNotEmpty)
                            _HeaderLine(
                              Icons.phone_outlined,
                              user!.phoneNumber!,
                            ),
                          if ((user?.email ?? '').isNotEmpty)
                            _HeaderLine(Icons.mail_outline, user!.email!),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => open(Routes.editProfile),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black87),
                      textStyle: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                item(Icons.history, 'Activities', () => open(Routes.activity)),
                item(Icons.location_on, 'Saved Address',
                    () => open(Routes.savedAddresses)),
                item(
                  Icons.notifications_none,
                  'Notifications',
                  () => open(Routes.notifications),
                  trailing: unread > 0
                      ? _CountBadge(count: unread)
                      : const Icon(Icons.chevron_right,
                          color: AppColors.neutral600),
                ),
                item(Icons.credit_card, 'Payment Methods',
                    () => open(Routes.paymentMethods)),
                item(Icons.tune, 'Settings', () => open(Routes.settings)),
                item(Icons.help, 'Help & Support', () {
                  Navigator.of(context).pop();
                  showFirstTimeUserGuide(rootContext, markAsSeen: false);
                }),
                item(Icons.star_border, 'Rate us', () {
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Rate us is coming soon.')),
                  );
                }),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    size: 28,
                    color: AppColors.brandPressed,
                  ),
                  title: Text(
                    'Delete Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPressed,
                    ),
                  ),
                  // Keep the drawer open while the dialog runs: signing out or
                  // deleting navigates away on success.
                  onTap: () => confirmAndDeleteAccount(context, ref),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.brand,
            child: InkWell(
              onTap: () => confirmAndSignOut(context, ref),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 28, color: Colors.black),
                      const SizedBox(width: 20),
                      Text(
                        'Logout',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.black87),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}
