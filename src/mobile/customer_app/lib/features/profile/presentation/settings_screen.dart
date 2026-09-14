import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/widgets.dart';
import '../application/notification_prefs_controller.dart';
import '../domain/notification_prefs.dart';
import 'widgets/settings_group_card.dart';
import 'widgets/settings_row.dart';

/// App settings: notification mute toggles, theme note, legal links, app
/// version and sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // App version is a static stub until wired to PackageInfo.
  static const _appVersion = '1.0.0 (1)';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          const SectionHeader(title: 'Notifications'),
          const SizedBox(height: AppSpacing.sm),
          prefs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: LoadingView(),
            ),
            error: (e, _) => ErrorView(
              message: 'Could not load notification settings.',
              onRetry: () => ref.invalidate(notificationPrefsProvider),
            ),
            data: (p) => _PrefsCard(prefs: p),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Appearance'),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              SettingsRow(
                icon: _themeModeIcon(themeMode),
                label: 'Theme',
                onTap: () => _pickTheme(context, ref, themeMode),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      label: _themeModeLabel(themeMode),
                      kind: StatusKind.neutral,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Legal'),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              SettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _comingSoon(context, 'Terms of Service'),
              ),
              SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _comingSoon(context, 'Privacy Policy'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'About'),
          const SizedBox(height: AppSpacing.sm),
          SettingsGroupCard(
            children: [
              SettingsRow(
                icon: Icons.info_outline,
                label: 'App version',
                trailing: Text(
                  _appVersion,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.secondary,
            icon: Icons.logout,
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what opens in your browser (coming soon).')),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final selected = await showAppBottomSheet<ThemeMode>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Theme'),
          for (final mode in const [
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.system,
          ])
            _ThemeOption(mode: mode, selected: mode == current),
        ],
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setMode(selected);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out',
      message: 'You will need to sign in again to book a taxi.',
      confirmLabel: 'Sign out',
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

class _PrefsCard extends ConsumerWidget {
  const _PrefsCard({required this.prefs});

  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(NotificationPrefs next) =>
        ref.read(notificationPrefsProvider.notifier).savePrefs(next);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          _ToggleRow(
            title: 'Cash bookings',
            subtitle: 'Updates for pay-on-the-day trips',
            value: prefs.cashBooking,
            onChanged: (v) => update(prefs.copyWith(cashBooking: v)),
          ),
          _ToggleRow(
            title: 'Web bookings',
            subtitle: 'Updates for trips booked in the app',
            value: prefs.webBooking,
            onChanged: (v) => update(prefs.copyWith(webBooking: v)),
          ),
          _ToggleRow(
            title: 'Cancellations',
            subtitle: 'When a trip is cancelled',
            value: prefs.cancellations,
            onChanged: (v) => update(prefs.copyWith(cancellations: v)),
          ),
          _ToggleRow(
            title: 'Job timeouts',
            subtitle: 'When no driver is found in time',
            value: prefs.jobTimeouts,
            onChanged: (v) => update(prefs.copyWith(jobTimeouts: v)),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Adaptive so iOS users get the native Cupertino switch feel.
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outline),
      ],
    );
  }
}

IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_6_outlined,
    };

String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

String _themeModeSubtitle(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Always light',
      ThemeMode.dark => 'Always dark',
      ThemeMode.system => 'Match device setting',
    };

/// One selectable row in the theme picker sheet. Pops its [mode] when tapped.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode, required this.selected});

  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final foreground = selected ? accent : theme.textTheme.titleMedium?.color;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Navigator.of(context).pop(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(_themeModeIcon(mode), size: 24, color: foreground),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _themeModeLabel(mode),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _themeModeSubtitle(mode),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check, color: accent, size: 22),
          ],
        ),
      ),
    );
  }
}
