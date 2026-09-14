import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/place.dart';
import '../../../core/location/location_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/booking_draft_controller.dart';
import 'widgets/widgets.dart';

/// Home TAB root (wired by the app shell — NOT in `bookingRoutes`).
///
/// Matches GoRide frame 30439:391: a full-bleed map with floating controls, and
/// a bottom card titled "Where to?" holding a rounded search field and a
/// horizontally-scrolling row of saved-place shortcut pills.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final firstName = _firstName(user?.fullName);

    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed map background (placeholder until Maps keys land).
          const Positioned.fill(child: MapView()),

          // Greeting pinned top-left, above the safe area.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.topLeft,
                child: _GreetingBadge(
                  greeting: firstName == null
                      ? 'Where are you going?'
                      : 'Hi $firstName',
                ),
              ),
            ),
          ),

          // Recenter control floating bottom-right above the booking card
          // (GoRide places a locate-me chip over the map).
          Align(
            alignment: Alignment.bottomRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                child: CircleIconButton.filled(
                  icon: Icons.my_location,
                  onTap: () => _recenter(context, ref),
                  tooltip: 'Recenter',
                ),
              ),
            ),
          ),

          // The booking card anchored to the bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: _BookingCard(),
          ),
        ],
      ),
    );
  }

  String? _firstName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(' ').first;
  }

  /// Recenter on the device location. When location is unavailable we don't
  /// loop the prompt or hard-fail — we nudge the user to enter pickup manually.
  Future<void> _recenter(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (result.needsManualEntry) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Location off — enter your pickup address.'),
          ),
        );
    }
    // A granted fix will drive the map camera once Maps keys land; no-op today.
  }
}

class _GreetingBadge extends StatelessWidget {
  const _GreetingBadge({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(greeting, style: theme.textTheme.titleMedium),
    );
  }
}

/// The bottom "Where to?" card — a rounded-top sheet over the map.
class _BookingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Saved places: AuthUser carries none today — mock shortcuts.
    // TODO: source from a real saved-addresses endpoint when profile lands.
    const savedPlaces = _mockSavedPlaces;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where to?', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),

              // Rounded "Enter location" search field (opens dropoff search).
              InkWell(
                onTap: () => _openDestinationSearch(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Enter location',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Horizontally-scrolling saved-place shortcut pills.
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
                      onTap: () =>
                          _selectDestination(context, ref, saved.place),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String label) => switch (label.toLowerCase()) {
        'home' => Icons.home_outlined,
        'office' || 'work' => Icons.work_outline,
        'apartment' => Icons.apartment_outlined,
        _ => Icons.bookmark_border,
      };

  void _openDestinationSearch(BuildContext context) {
    context.push(Routes.addressSearch, extra: 'dropoff');
  }

  /// Picking a saved destination sets it on the draft and jumps to the address
  /// screen in pickup mode so the user just confirms pickup.
  void _selectDestination(BuildContext context, WidgetRef ref, Place place) {
    ref.read(bookingDraftProvider.notifier).setDropoff(place);
    context.push(Routes.addressSearch, extra: 'pickup');
  }
}

// ── Mock data (until saved-addresses endpoint exists) ─────────────────────

const _mockSavedPlaces = <SavedPlace>[
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
