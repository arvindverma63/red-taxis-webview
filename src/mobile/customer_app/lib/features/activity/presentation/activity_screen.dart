import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../booking/application/booking_draft_controller.dart';
import '../application/activity_controller.dart';
import '../data/activity_repository.dart';
import '../domain/booking_summary.dart';
import 'widgets/route_path.dart';
import 'widgets/vehicle_avatar.dart';

/// Professional, full-featured Activity & Trip History Screen.
/// Features an executive telemetry metrics grid, filter tabs with live item counters,
/// real-time query search, switchable Card Grid / List view layouts, and an
/// interactive ticket receipt breakdown modal.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActivityFilter { all, ongoing, scheduled, completed, canceled }

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _isGrid = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityControllerProvider);
    final isOffline = ref.watch(activityIsOfflineProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Activity'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGrid ? 'Switch to list view' : 'Switch to grid view',
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh trips',
            onPressed: () =>
                ref.read(activityControllerProvider.notifier).refresh(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
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
          data: (allBookings) {
            // Compute telemetry metrics dynamically
            final totalTrips = allBookings.length;
            final completedTrips =
                allBookings.where((b) => b.isCompleted).toList();
            final ongoingTrips = allBookings.where((b) => b.isOngoing).toList();
            final scheduledTrips =
                allBookings.where((b) => b.isAwaitingScheduled).toList();
            final canceledTrips =
                allBookings.where((b) => b.isCancelled).toList();
            // Filter by active tab
            List<BookingSummary> filteredList = switch (_filter) {
              _ActivityFilter.all => allBookings,
              _ActivityFilter.ongoing => ongoingTrips,
              _ActivityFilter.scheduled => scheduledTrips,
              _ActivityFilter.completed => completedTrips,
              _ActivityFilter.canceled => canceledTrips,
            };

            // Filter by search query if present
            if (_searchQuery.isNotEmpty) {
              filteredList = filteredList.where((b) {
                final pickup = b.pickup.description.toLowerCase();
                final dropoff = b.dropoff.description.toLowerCase();
                final id = b.id.toLowerCase();
                final vehicle = b.vehicleName.toLowerCase();
                return pickup.contains(_searchQuery) ||
                    dropoff.contains(_searchQuery) ||
                    id.contains(_searchQuery) ||
                    vehicle.contains(_searchQuery);
              }).toList();
            }

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(activityControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  // Offline Indicator Banner (when working without internet)
                  if (isOffline) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                          width: AppStroke.thin,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Offline mode • Displaying saved trip history',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Search & Filter Bar
                  _ActivitySearchBar(
                    controller: _searchController,
                    onClear: () => _searchController.clear(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Filter Segment Pills with item counters
                  _FilterChipsRow(
                    currentFilter: _filter,
                    allCount: totalTrips,
                    ongoingCount: ongoingTrips.length,
                    scheduledCount: scheduledTrips.length,
                    completedCount: completedTrips.length,
                    canceledCount: canceledTrips.length,
                    onSelect: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. View Header (Item counter + view layout badge)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredList.length} ${filteredList.length == 1 ? "Trip" : "Trips"} found',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isGrid
                                  ? Icons.grid_view_rounded
                                  : Icons.view_list_rounded,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _isGrid ? 'Grid' : 'List',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Trip List / Grid Display
                  if (filteredList.isEmpty) ...[
                    _EmptyFilterView(
                      filter: _filter,
                      searchQuery: _searchQuery,
                      onClearSearch: () => _searchController.clear(),
                    ),
                  ] else if (_isGrid) ...[
                    // Grid / Card Deck View
                    ...filteredList.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ActivityTripCard(
                          booking: b,
                          onTap: () => _openDetail(context, b),
                          onTrack: () =>
                              context.push('${Routes.tracking}/${b.id}'),
                          onReceipt: () => _showReceiptSheet(context, b),
                          onRebook: () => _rebook(context, ref, b),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Compact Divided List View
                    ...filteredList.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ActivityTripRow(
                          booking: b,
                          onTap: () => _openDetail(context, b),
                          onReceipt: () => _showReceiptSheet(context, b),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, BookingSummary b) {
    context.push('${Routes.bookingDetail}/${b.id}');
  }

  void _rebook(BuildContext context, WidgetRef ref, BookingSummary b) {
    ref.read(bookingDraftProvider.notifier).setDropoff(b.dropoff);
    context.push(Routes.addressSearch, extra: 'pickup');
  }

  void _showReceiptSheet(BuildContext context, BookingSummary b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketReceiptSheet(booking: b),
    );
  }
}

// ── 1. Search Bar ─────────────────────────────────────────────────────────

class _ActivitySearchBar extends StatelessWidget {
  const _ActivitySearchBar({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.4),
          width: AppStroke.thin,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.neutral500,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search address, booking #ID or vehicle…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.cancel_rounded,
                size: 18,
                color: AppColors.neutral400,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 3. Filter Segment Pills with item counters ─────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.currentFilter,
    required this.allCount,
    required this.ongoingCount,
    required this.scheduledCount,
    required this.completedCount,
    required this.canceledCount,
    required this.onSelect,
  });

  final _ActivityFilter currentFilter;
  final int allCount;
  final int ongoingCount;
  final int scheduledCount;
  final int completedCount;
  final int canceledCount;
  final ValueChanged<_ActivityFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _PillItem(
            label: 'All',
            count: allCount,
            isSelected: currentFilter == _ActivityFilter.all,
            onTap: () => onSelect(_ActivityFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          _PillItem(
            label: 'Ongoing',
            count: ongoingCount,
            accentColor: AppColors.info,
            isSelected: currentFilter == _ActivityFilter.ongoing,
            onTap: () => onSelect(_ActivityFilter.ongoing),
          ),
          const SizedBox(width: AppSpacing.sm),
          _PillItem(
            label: 'Scheduled',
            count: scheduledCount,
            accentColor: AppColors.warning,
            isSelected: currentFilter == _ActivityFilter.scheduled,
            onTap: () => onSelect(_ActivityFilter.scheduled),
          ),
          const SizedBox(width: AppSpacing.sm),
          _PillItem(
            label: 'Completed',
            count: completedCount,
            accentColor: AppColors.success,
            isSelected: currentFilter == _ActivityFilter.completed,
            onTap: () => onSelect(_ActivityFilter.completed),
          ),
          const SizedBox(width: AppSpacing.sm),
          _PillItem(
            label: 'Cancelled',
            count: canceledCount,
            accentColor: AppColors.error,
            isSelected: currentFilter == _ActivityFilter.canceled,
            onTap: () => onSelect(_ActivityFilter.canceled),
          ),
        ],
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accentColor ?? AppColors.brand;

    return Material(
      color: isSelected ? color : scheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? color : scheme.outline.withValues(alpha: 0.5),
          width: AppStroke.thin,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? Colors.white : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 4. Professional Activity Trip Card (Grid Mode) ─────────────────────────

class _ActivityTripCard extends StatelessWidget {
  const _ActivityTripCard({
    required this.booking,
    required this.onTap,
    required this.onTrack,
    required this.onReceipt,
    required this.onRebook,
  });

  final BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final VoidCallback onReceipt;
  final VoidCallback onRebook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isLive = booking.isOngoing;
    final isDone = booking.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isLive
              ? AppColors.info.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.35),
          width: isLive ? 1.5 : AppStroke.thin,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isLive ? 0.08 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Vehicle Badge + #ID + Status Chip
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                VehicleAvatar(vehicleName: booking.vehicleName, size: 36),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.vehicleName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: booking.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied Booking #${booking.id}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#${booking.id}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: _statusLabel(booking),
                  kind: _statusKind(booking),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Route Block
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: RoutePath(
              pickup: booking.pickup,
              dropoff: booking.dropoff,
              showPostcodes: true,
            ),
          ),

          // Meta Row: Date & Time, Price, Payment
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      Fmt.dateTime(booking.scheduledFor),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      Fmt.money(booking.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        booking.paymentMethod,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons Dock
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (isLive) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('Details'),
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: AppButton(
                      label: 'Track Live',
                      icon: Icons.navigation_rounded,
                      onPressed: onTrack,
                    ),
                  ),
                ] else if (isDone) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Details'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded, size: 14),
                      label: const Text('Receipt'),
                      onPressed: onReceipt,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 14),
                      label: const Text('Rebook'),
                      onPressed: onRebook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('View Details'),
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Professional Activity Trip Row (List Mode) ──────────────────────────

class _ActivityTripRow extends StatelessWidget {
  const _ActivityTripRow({
    required this.booking,
    required this.onTap,
    required this.onReceipt,
  });

  final BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.35),
          width: AppStroke.thin,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                VehicleAvatar(vehicleName: booking.vehicleName, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.dropoff.description,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.dateTime(booking.scheduledFor)} • #${booking.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StatusChip(
                        label: _statusLabel(booking),
                        kind: _statusKind(booking),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.money(booking.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      booking.paymentMethod,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onTap,
                          child: Text(
                            'Details',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (booking.isCompleted) ...[
                          const SizedBox(width: AppSpacing.sm),
                          GestureDetector(
                            onTap: onReceipt,
                            child: Text(
                              'Receipt',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 6. Empty View for Filter/Search ────────────────────────────────────────

class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView({
    required this.filter,
    required this.searchQuery,
    required this.onClearSearch,
  });

  final _ActivityFilter filter;
  final String searchQuery;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final title = searchQuery.isNotEmpty
        ? 'No matching trips found'
        : switch (filter) {
            _ActivityFilter.all => 'No trips yet',
            _ActivityFilter.ongoing => 'No ongoing trips',
            _ActivityFilter.scheduled => 'No scheduled trips',
            _ActivityFilter.completed => 'No completed trips',
            _ActivityFilter.canceled => 'No canceled trips',
          };

    final subtitle = searchQuery.isNotEmpty
        ? 'Try clearing your search query "$searchQuery"'
        : switch (filter) {
            _ActivityFilter.all => 'Your booked taxi trips will appear here.',
            _ActivityFilter.ongoing =>
              'Active rides with an assigned driver appear here.',
            _ActivityFilter.scheduled =>
              'Trips scheduled for future dates appear here.',
            _ActivityFilter.completed =>
              'Past journeys and downloadable receipts appear here.',
            _ActivityFilter.canceled =>
              'Cancelled rides and refund status appear here.',
          };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (searchQuery.isNotEmpty) ...[
            OutlinedButton(
              onPressed: onClearSearch,
              child: const Text('Clear Search'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => context.go(Routes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
              ),
              child: const Text('Book a Ride'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 7. Luxury Ticket Receipt Bottom Sheet ──────────────────────────────────

class _TicketReceiptSheet extends StatelessWidget {
  const _TicketReceiptSheet({required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Brand Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'RED TAXI OFFICIAL RECEIPT',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              StatusChip(
                label: 'PAID',
                kind: StatusKind.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Large Fare Display
          Center(
            child: Column(
              children: [
                Text(
                  Fmt.money(booking.price),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.brand,
                  ),
                ),
                Text(
                  'Payment via ${booking.paymentMethod}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Dashed Divider with Ticket Notches
          Row(
            children: [
              Container(
                width: 14,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _DashedLinePainter(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
                  child: const SizedBox(height: 1),
                ),
              ),
              Container(
                width: 14,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Metadata Grid
          _ReceiptMetadataRow(label: 'Booking ID', value: '#${booking.id}'),
          const SizedBox(height: AppSpacing.sm),
          _ReceiptMetadataRow(
            label: 'Date & Time',
            value: Fmt.dateTime(booking.scheduledFor),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReceiptMetadataRow(
            label: 'Vehicle Class',
            value: booking.vehicleName,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReceiptMetadataRow(
            label: 'Passenger(s)',
            value: '${booking.passengers} Passenger(s)',
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          // Route Details
          Text(
            'JOURNEY SUMMARY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RoutePath(
            pickup: booking.pickup,
            dropoff: booking.dropoff,
            showPostcodes: true,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),

          // Itemized Charges
          Text(
            'FARE BREAKDOWN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReceiptMetadataRow(
            label: 'Base Journey Rate',
            value: '£${(booking.price * 0.85).toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.xs),
          _ReceiptMetadataRow(
            label: 'Distance & Telemetry',
            value: '£${(booking.price * 0.15).toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount Settled',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                Fmt.money(booking.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Actions: Copy / Share / Close
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Receipt'),
                  onPressed: () {
                    final text = '''
RED TAXI OFFICIAL RECEIPT
Booking Ref: #${booking.id}
Date: ${Fmt.dateTime(booking.scheduledFor)}
From: ${booking.pickup.description}
To: ${booking.dropoff.description}
Vehicle: ${booking.vehicleName}
Total Settled: ${Fmt.money(booking.price)} via ${booking.paymentMethod}
''';
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Receipt copied to clipboard!'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptMetadataRow extends StatelessWidget {
  const _ReceiptMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Helpers ────────────────────────────────────────────────────────────────

StatusKind _statusKind(BookingSummary b) {
  if (b.isCompleted) return StatusKind.success;
  if (b.isCancelled) return StatusKind.danger;
  if (b.isDriverEngaged) return StatusKind.active;
  return StatusKind.pending;
}

String _statusLabel(BookingSummary b) {
  if (b.isCompleted) return 'Completed';
  if (b.isCancelled) return 'Cancelled';
  if (b.isDriverEngaged) return 'In Progress';
  if (b.isAwaitingScheduled) return 'Scheduled';
  return 'Requested';
}
