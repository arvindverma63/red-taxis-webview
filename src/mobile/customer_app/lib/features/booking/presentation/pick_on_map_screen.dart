import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/place.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/booking_draft_controller.dart';
import 'address_search_screen.dart';
import 'widgets/widgets.dart';

/// "Set pickup location" — GoRide frame 30439:395. A full-bleed map with a
/// fixed centre pin, floating back / recenter controls, and a bottom
/// confirm card ([MapPinConfirmCard]) showing the resolved address with a
/// "Next" CTA.
///
/// Wiring is preserved: confirming sets the chosen end on the draft (pickup or
/// dropoff per [mode]) and routes onward exactly like the typed search flow —
/// to review when both ends are known, otherwise to pickup. The "edit" pencil
/// returns to the typed [AddressSearchScreen] for the same mode.
///
/// Note: the platform has no reverse-geocode endpoint yet, so the card reflects
/// the end already chosen for this mode (or prompts the user to type). When
/// reverse geocoding lands, wire the map's idle camera target through
/// `resolveAddress` and update the card live.
class PickOnMapScreen extends ConsumerWidget {
  const PickOnMapScreen({super.key, required this.mode});

  final AddressMode mode;

  bool get _isPickup => mode == AddressMode.pickup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final draft = ref.watch(bookingDraftProvider);
    final place = _isPickup ? draft.pickup : draft.dropoff;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: MapView()),

          // Fixed centre pin over the map.
          const Center(
            child: Padding(
              // Lift the pin tip to the visual centre.
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 48, color: AppColors.brand),
            ),
          ),

          // Floating back control top-left.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.topLeft,
                child: CircleIconButton.filled(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            ),
          ),

          // Confirm card pinned to the bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: MapPinConfirmCard(
              title: _isPickup ? 'Set pickup location' : 'Set destination',
              addressTitle: place?.description ??
                  (_isPickup ? 'Choose your pickup' : 'Choose your destination'),
              addressSubtitle: place?.addressLine.isNotEmpty == true
                  ? place!.addressLine
                  : place?.postcode,
              actionLabel: 'Next',
              onAction: place == null
                  ? () => _editTyped(context)
                  : () => _confirm(context, ref, place),
              onEdit: () => _editTyped(context),
            ),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }

  /// Advance using the already-chosen [place] (mirrors the typed-search routing).
  void _confirm(BuildContext context, WidgetRef ref, Place place) {
    final notifier = ref.read(bookingDraftProvider.notifier);
    if (_isPickup) {
      notifier.setPickup(place);
    } else {
      notifier.setDropoff(place);
    }
    final draft = ref.read(bookingDraftProvider);
    if (draft.hasRoute) {
      context.go(Routes.bookingReview);
    } else {
      context.pushReplacement(Routes.addressSearch, extra: 'pickup');
    }
  }

  /// Fall back to typed search for this mode (also the "edit" affordance).
  void _editTyped(BuildContext context) {
    context.pushReplacement(Routes.addressSearch, extra: mode.name);
  }
}
