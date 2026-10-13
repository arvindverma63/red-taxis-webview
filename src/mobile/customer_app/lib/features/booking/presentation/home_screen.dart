import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/place.dart';
import '../../../core/location/location_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../activity/application/activity_controller.dart';
import '../../activity/domain/booking_summary.dart';
import '../../profile/application/saved_addresses_controller.dart';
import '../application/booking_draft_controller.dart';
import 'booking_routes.dart';
import 'widgets/pill_chip.dart';

/// Clean, native GoRide Home Screen.
/// Provides an intuitive passenger home dashboard with personalized greeting,
/// destination search, quick ride modes, active ride tracking, and saved places,
/// without rendering any static or placeholder maps.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final firstName = _firstName(user?.fullName);
    final ongoingBookings = ref.watch(ongoingBookingsProvider);
    final completedBookings = ref.watch(completedBookingsProvider);
    final savedPlacesAsync = ref.watch(savedAddressesProvider);
    final savedPlaces = savedPlacesAsync.valueOrNull ?? _fallbackSavedPlaces;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
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
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Red Taxi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined),
            tooltip: 'Contact Dispatch',
            onPressed: () => _callSupport(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'My Account',
            onPressed: () => context.go(Routes.profile),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // 1. Personalized Greeting
            _GreetingSection(firstName: firstName),
            const SizedBox(height: AppSpacing.lg),

            // 2. Active Trip Banner (if user has an in-flight booking)
            if (ongoingBookings.isNotEmpty) ...[
              _ActiveRideBanner(booking: ongoingBookings.first),
              const SizedBox(height: AppSpacing.md),
            ],

            // 3. "Where to?" Destination Search Card
            _WhereToCard(
              onTapDropoff: () => _openDestinationSearch(context),
              onTapPickup: () => _openPickupSearch(context, ref),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 4. Quick Ride Modes (Ride Now, Schedule, Saved, Pick Map)
            _QuickActionsGrid(
              onRideNow: () => _openDestinationSearch(context),
              onSchedule: () => _openDestinationSearch(context),
              onSavedPlaces: () => context.push(Routes.savedAddresses),
              onPickOnMap: () => context.push(kPickOnMapPath, extra: 'dropoff'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 5. Saved Places Shortcuts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Places',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.savedAddresses),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: savedPlaces.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final saved = savedPlaces[i];
                  return PillChip(
                    icon: _iconFor(saved.label),
                    label: saved.label,
                    onTap: () => _selectDestination(context, ref, saved.place),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 6. Recent Trips / Rebook (if completed bookings exist)
            if (completedBookings.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Trips',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.activity),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ...completedBookings.take(2).map(
                    (b) => _RecentTripCard(
                      booking: b,
                      onRebook: () =>
                          _selectDestination(context, ref, b.dropoff),
                      onDetails: () =>
                          context.push('${Routes.bookingDetail}/${b.id}'),
                    ),
                  ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // 7. Trust & Service Standards Banner
            const _ServiceStandardsCard(),
          ],
        ),
      ),
    );
  }

  String? _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(' ').first;
  }

  void _openDestinationSearch(BuildContext context) {
    context.push(Routes.addressSearch, extra: 'dropoff');
  }

  Future<void> _openPickupSearch(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (result.needsManualEntry && context.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Location unavailable. Enter pickup address.'),
          ),
        );
      context.push(Routes.addressSearch, extra: 'pickup');
      return;
    }
    if (context.mounted) {
      context.push(Routes.addressSearch, extra: 'pickup');
    }
  }

  void _selectDestination(BuildContext context, WidgetRef ref, Place place) {
    ref.read(bookingDraftProvider.notifier).setDropoff(place);
    context.push(Routes.addressSearch, extra: 'pickup');
  }

  Future<void> _callSupport(BuildContext context) async {
    const phone = '+441747850888';
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch office: $phone')),
      );
    }
  }

  IconData _iconFor(String label) => switch (label.toLowerCase()) {
        'home' => Icons.home_outlined,
        'office' || 'work' => Icons.work_outline,
        'apartment' => Icons.apartment_outlined,
        _ => Icons.bookmark_border,
      };
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting =
        firstName == null ? 'Welcome to Red Taxi' : 'Hello, $firstName 👋';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Where would you like to go today?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.35),
          width: AppStroke.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Ride in Progress',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '£${booking.price.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'To: ${booking.dropoff.addressLine.isNotEmpty ? booking.dropoff.addressLine : booking.dropoff.description}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('Details'),
                  onPressed: () =>
                      context.push('${Routes.bookingDetail}/${booking.id}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Track Live Ride',
                  icon: Icons.navigation_rounded,
                  onPressed: () =>
                      context.push('${Routes.tracking}/${booking.id}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhereToCard extends StatelessWidget {
  const _WhereToCard({
    required this.onTapDropoff,
    required this.onTapPickup,
  });

  final VoidCallback onTapDropoff;
  final VoidCallback onTapPickup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.5),
          width: AppStroke.thin,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pickup row
          InkWell(
            onTap: onTapPickup,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Current Location',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_location_alt_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(
              height: 16,
              width: 2,
              color: scheme.outline.withValues(alpha: 0.4),
            ),
          ),
          // Dropoff row (Where to?)
          InkWell(
            onTap: onTapDropoff,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.25),
                  width: AppStroke.thin,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Where to? Enter destination',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onRideNow,
    required this.onSchedule,
    required this.onSavedPlaces,
    required this.onPickOnMap,
  });

  final VoidCallback onRideNow;
  final VoidCallback onSchedule;
  final VoidCallback onSavedPlaces;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.local_taxi_rounded,
            iconColor: AppColors.brand,
            label: 'Ride Now',
            onTap: onRideNow,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.info,
            label: 'Schedule',
            onTap: onSchedule,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.bookmark_outline_rounded,
            iconColor: AppColors.warning,
            label: 'Saved',
            onTap: onSavedPlaces,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionTile(
            icon: Icons.map_outlined,
            iconColor: AppColors.success,
            label: 'Pick Map',
            onTap: onPickOnMap,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.35),
              width: AppStroke.thin,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTripCard extends StatelessWidget {
  const _RecentTripCard({
    required this.booking,
    required this.onRebook,
    required this.onDetails,
  });

  final BookingSummary booking;
  final VoidCallback onRebook;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.35),
              width: AppStroke.thin,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.dropoff.addressLine.isNotEmpty
                          ? booking.dropoff.addressLine
                          : booking.dropoff.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '£${booking.price.toStringAsFixed(2)} • ${booking.vehicleName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: onDetails,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text('Details'),
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton(
                onPressed: onRebook,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text('Rebook'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceStandardsCard extends StatelessWidget {
  const _ServiceStandardsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.25),
          width: AppStroke.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Red Taxi Standard',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _StandardRow(
            icon: Icons.verified_user_outlined,
            title: 'Licensed & Verified Drivers',
            subtitle: 'Professional, local drivers vetted for your safety',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _StandardRow(
            icon: Icons.price_check_outlined,
            title: 'Fixed & Transparent Fares',
            subtitle: 'No surge pricing surprises, upfront fare quotes',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _StandardRow(
            icon: Icons.support_agent_outlined,
            title: '24/7 Local Dispatch Help',
            subtitle: 'Direct telephone and operator support anytime',
          ),
        ],
      ),
    );
  }
}

class _StandardRow extends StatelessWidget {
  const _StandardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _fallbackSavedPlaces = <SavedPlace>[
  SavedPlace(
    id: 'home',
    label: 'Home',
    place: Place(
      description: 'Home',
      postcode: 'SP8 4AA',
      addressLine: 'Set your home address in Profile',
    ),
  ),
  SavedPlace(
    id: 'office',
    label: 'Office',
    place: Place(
      description: 'Office',
      postcode: 'SP7 8PX',
      addressLine: 'Set your work address in Profile',
    ),
  ),
  SavedPlace(
    id: 'apartment',
    label: 'Apartment',
    place: Place(
      description: 'Apartment',
      postcode: 'SP8 4QT',
      addressLine: 'Set a saved address in Profile',
    ),
  ),
];
