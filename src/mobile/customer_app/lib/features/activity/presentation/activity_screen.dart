import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/activity_controller.dart';
import '../domain/booking_summary.dart';
import 'widgets/booking_list_row.dart';
import 'widgets/ongoing_booking_card.dart';

/// The Activity tab root: the customer's trips split across the four GoRide
/// activity tabs — Ongoing, Scheduled, Completed and Canceled (frames
/// `30439:426`/`427`/`429`/`431`). The main shell wires this in as a tab (not a
/// pushed route), so it owns its own [AppBar]/[TabBar] chrome here.
///
/// All four buckets derive from the same [activityControllerProvider] data via
/// the booking's status — no controller/repository changes. The Ongoing tab uses
/// the richer [OngoingBookingCard] (route block + Track Route); the other three
/// use the compact [BookingListRow]. Tapping any row opens the ride details
/// (`/activity/:bookingId`).
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityControllerProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity'),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Ongoing'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Completed'),
              Tab(text: 'Canceled'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: state.when(
            loading: () => const LoadingView(message: 'Loading your trips…'),
            error: (error, _) => ErrorView(
              message: error is ApiException
                  ? error.message
                  : 'We couldn’t load your trips.',
              onRetry: () =>
                  ref.read(activityControllerProvider.notifier).refresh(),
            ),
            data: (_) => TabBarView(
              children: [
                _BookingTab(
                  bookings: ref.watch(ongoingBookingsProvider),
                  variant: _TabVariant.ongoing,
                  emptyTitle: 'No ongoing trips',
                  emptySubtitle: 'Your live trip appears here once a driver is '
                      'on the way.',
                  emptyIcon: Icons.local_taxi_outlined,
                ),
                _BookingTab(
                  bookings: ref.watch(scheduledBookingsProvider),
                  variant: _TabVariant.scheduled,
                  emptyTitle: 'No scheduled trips',
                  emptySubtitle: 'Trips you book ahead of time appear here.',
                  emptyIcon: Icons.event_outlined,
                ),
                _BookingTab(
                  bookings: ref.watch(completedBookingsProvider),
                  variant: _TabVariant.completed,
                  emptyTitle: 'No completed trips yet',
                  emptySubtitle: 'Finished trips and receipts appear here.',
                  emptyIcon: Icons.check_circle_outline,
                ),
                _BookingTab(
                  bookings: ref.watch(canceledBookingsProvider),
                  variant: _TabVariant.canceled,
                  emptyTitle: 'No canceled trips',
                  emptySubtitle: 'Cancelled and refunded trips appear here.',
                  emptyIcon: Icons.cancel_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which GoRide tab a list belongs to — drives the row presentation.
enum _TabVariant { ongoing, scheduled, completed, canceled }

/// A pull-to-refreshable list of bookings rendered per [variant], or an empty
/// state. Ongoing uses cards; the rest use compact divided rows.
class _BookingTab extends ConsumerWidget {
  const _BookingTab({
    required this.bookings,
    required this.variant,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  final List<BookingSummary> bookings;
  final _TabVariant variant;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  Future<void> _refresh(WidgetRef ref) =>
      ref.read(activityControllerProvider.notifier).refresh();

  void _openDetail(BuildContext context, BookingSummary b) =>
      context.push('${Routes.bookingDetail}/${b.id}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bookings.isEmpty) {
      // Keep pull-to-refresh working on an empty list.
      return RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: EmptyView(
                title: emptyTitle,
                subtitle: emptySubtitle,
                icon: emptyIcon,
              ),
            ),
          ],
        ),
      );
    }

    // Ongoing: spacious cards. Others: compact rows separated by hairlines.
    if (variant == _TabVariant.ongoing) {
      return RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return OngoingBookingCard(
              booking: booking,
              onTap: () => _openDetail(context, booking),
              onTrack: () =>
                  context.push('${Routes.tracking}/${booking.id}'),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: bookings.length,
        separatorBuilder: (context, __) => Divider(
          height: AppStroke.thin,
          thickness: AppStroke.thin,
          color: Theme.of(context).colorScheme.outline,
        ),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return BookingListRow(
            booking: booking,
            trailingLabel: _trailingLabel(booking),
            trailingDanger: variant == _TabVariant.canceled,
            onTap: () => _openDetail(context, booking),
          );
        },
      ),
    );
  }

  /// The secondary right-column line per tab: the refund status for canceled
  /// trips, otherwise the payment method (matching the GoRide rows).
  String _trailingLabel(BookingSummary b) =>
      variant == _TabVariant.canceled ? 'Canceled & Refunded' : b.paymentMethod;
}
