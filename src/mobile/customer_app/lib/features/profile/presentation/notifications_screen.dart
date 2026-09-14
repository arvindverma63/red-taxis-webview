import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../application/notifications_controller.dart';
import '../domain/notification_item.dart';

/// The customer's notification inbox: booking lifecycle events. Tapping an item
/// marks it read and, when it carries a booking id, deep-links to the booking.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final hasItems = notifications.valueOrNull?.isNotEmpty ?? false;

    return AppScaffold(
      title: 'Notifications',
      actions: [
        if (hasItems)
          TextButton(
            onPressed: () => _clearAll(context, ref),
            child: const Text('Clear all'),
          ),
      ],
      body: notifications.when(
        loading: () => const LoadingView(message: 'Loading notifications…'),
        error: (e, _) => ErrorView(
          message: 'Could not load your notifications.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.notifications_none,
              title: 'You are all caught up',
              subtitle: 'Booking updates and receipts will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) =>
                _NotificationTile(item: list[i]),
          );
        },
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear all',
      message: 'Remove all notifications from your inbox?',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(notificationsProvider.notifier).clearAll();
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, kind) = _visualFor(item.type);

    return AppCard(
      onTap: () => _open(context, ref),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _tintFor(kind).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: _tintFor(kind)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!item.read) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(item.body, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  Fmt.relative(item.time),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!item.read) {
      await ref.read(notificationsProvider.notifier).markRead(item.id);
    }
    final bookingId = item.bookingId;
    if (bookingId != null && bookingId.isNotEmpty && context.mounted) {
      context.push('${Routes.bookingDetail}/$bookingId');
    }
  }

  (IconData, StatusKind) _visualFor(String type) {
    switch (type) {
      case 'booking_confirmed':
        return (Icons.event_available, StatusKind.active);
      case 'driver_arriving':
        return (Icons.directions_car_filled, StatusKind.active);
      case 'driver_arrived':
        return (Icons.local_taxi, StatusKind.active);
      case 'booking_completed':
        return (Icons.check_circle_outline, StatusKind.success);
      case 'booking_cancelled':
        return (Icons.cancel_outlined, StatusKind.danger);
      case 'payment_receipt':
        return (Icons.receipt_long_outlined, StatusKind.neutral);
      default:
        return (Icons.notifications_outlined, StatusKind.neutral);
    }
  }

  Color _tintFor(StatusKind kind) => switch (kind) {
        StatusKind.pending => AppColors.warning,
        StatusKind.active => AppColors.info,
        StatusKind.success => AppColors.success,
        StatusKind.danger => AppColors.error,
        StatusKind.neutral => AppColors.neutral400,
      };
}
