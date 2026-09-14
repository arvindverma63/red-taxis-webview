import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/address_search_controller.dart';
import '../application/booking_draft_controller.dart';
import '../data/booking_repository.dart';
import '../domain/address_suggestion.dart';
import 'booking_routes.dart';
import 'widgets/widgets.dart';

/// Where the entered address gets stored on the draft.
enum AddressMode { pickup, dropoff }

/// Recent vs Suggested results tab (GoRide segmented toggle). Both render the
/// same live suggestion list today; the toggle is presentational until a
/// recents/saved endpoint lands. [_Tab.recent] is the default.
enum _Tab { recent, suggested }

/// Debounced autocomplete + suggestion list, styled to GoRide frames
/// 30439:393/394: a "Where do you want to go?" header, the grouped location
/// card (current location + destination input + add-stop), a row of shortcut
/// pills, a Recent/Suggested toggle, then the results list.
///
/// All wiring is unchanged from the original: input is debounced into
/// [addressQueryProvider]; selecting a row resolves it to a [Place], sets it on
/// the draft, and routes to review (both ends set) or back to pickup.
class AddressSearchScreen extends ConsumerStatefulWidget {
  const AddressSearchScreen({super.key, required this.mode});

  final AddressMode mode;

  @override
  ConsumerState<AddressSearchScreen> createState() =>
      _AddressSearchScreenState();
}

class _AddressSearchScreenState extends ConsumerState<AddressSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _resolving = false;
  _Tab _tab = _Tab.recent;

  /// On the pickup step we try once to use the device location. When it isn't
  /// available (permission denied/forever, services off, or error) we flip this
  /// so the user sees a "Location off — enter your pickup address" note and
  /// just types instead. Never blocks and never re-loops the permission prompt.
  bool _locationOff = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == AddressMode.pickup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocation());
    }
  }

  Future<void> _checkLocation() async {
    final result =
        await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    // A granted fix could later pre-fill pickup; for now we only need to know
    // whether to surface the manual-entry note.
    if (result.needsManualEntry) setState(() => _locationOff = true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(addressQueryProvider.notifier).state = value;
    });
  }

  bool get _isPickup => widget.mode == AddressMode.pickup;

  Future<void> _onSelect(AddressSuggestion suggestion) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _resolving = true);
    try {
      final repo = ref.read(bookingRepositoryProvider);
      final place = await repo.resolveAddress(suggestion.placeId);
      final draftNotifier = ref.read(bookingDraftProvider.notifier);
      if (_isPickup) {
        draftNotifier.setPickup(place);
      } else {
        draftNotifier.setDropoff(place);
      }

      final draft = ref.read(bookingDraftProvider);
      if (!mounted) return;

      if (draft.hasRoute) {
        // Both ends set — go straight to review.
        router.go(Routes.bookingReview);
      } else {
        // Only one end set — collect the other (pickup next).
        router.pushReplacement(Routes.addressSearch, extra: 'pickup');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_errorText(e))),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  String _errorText(Object e) {
    final msg = e.toString();
    return msg.startsWith('ApiException') || msg.isEmpty
        ? "Couldn't select that address. Please try again."
        : msg.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(addressQueryProvider);
    final suggestionsAsync = ref.watch(addressSuggestionsProvider(query));
    final theme = Theme.of(context);
    final hasQuery = query.trim().length >= 3;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: close + "Where do you want to go?" ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _isPickup
                          ? 'Set your pickup location'
                          : 'Where do you want to go?',
                      style: theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Location-off fallback note (pickup step only) ──────────────
            if (_isPickup && _locationOff)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: const LocationOffNote(),
              ),

            // ── Grouped location card ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LocationSearchCard(
                pickupLabel: _isPickup
                    ? 'Search your pickup address'
                    : 'Your current location',
                destinationController: _controller,
                destinationFocusNode: _focusNode,
                destinationHint: _isPickup ? 'Pickup address' : 'Where to?',
                onDestinationChanged: _onChanged,
                onAddStop: _isPickup ? null : () => _focusNode.requestFocus(),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Shortcut pills ─────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  PillChip(
                    icon: Icons.map_outlined,
                    label: 'Select from map',
                    onTap: _selectFromMap,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PillChip(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () {},
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PillChip(
                    icon: Icons.work_outline,
                    label: 'Office',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Recent / Suggested toggle (only before typing) ─────────────
            if (!hasQuery)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: SegmentedToggle(
                  segments: const ['Recent', 'Suggested'],
                  selectedIndex: _tab.index,
                  onChanged: (i) =>
                      setState(() => _tab = _Tab.values[i]),
                ),
              ),

            if (_resolving) const LinearProgressIndicator(),

            // ── Results ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _SuggestionList(
                  query: query,
                  suggestionsAsync: suggestionsAsync,
                  onSelect: _resolving ? null : _onSelect,
                  onRetry: () =>
                      ref.invalidate(addressSuggestionsProvider(query)),
                  emptyHint: _isPickup
                      ? 'Search for your pickup address'
                      : 'Search for your destination',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Select from map" — routes to the map-pin picker for this mode.
  void _selectFromMap() {
    context.push(kPickOnMapPath, extra: widget.mode.name);
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.query,
    required this.suggestionsAsync,
    required this.onSelect,
    required this.onRetry,
    required this.emptyHint,
  });

  final String query;
  final AsyncValue<List<AddressSuggestion>> suggestionsAsync;
  final ValueChanged<AddressSuggestion>? onSelect;
  final VoidCallback onRetry;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (query.trim().length < 3) {
      return EmptyView(
        icon: Icons.location_searching,
        title: emptyHint,
        subtitle: 'Enter at least 3 characters to search.',
      );
    }

    return suggestionsAsync.when(
      loading: () => const LoadingView(),
      error: (err, _) => ErrorView(
        message: _message(err),
        onRetry: onRetry,
      ),
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return const EmptyView(
            icon: Icons.search_off,
            title: 'No matches',
            subtitle: 'Try a different spelling or add the postcode.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          itemBuilder: (context, i) {
            final s = suggestions[i];
            return PlaceResultRow(
              title: s.mainText.isNotEmpty ? s.mainText : s.description,
              subtitle:
                  s.secondaryText.isNotEmpty ? s.secondaryText : s.postcode,
              onTap: onSelect == null ? null : () => onSelect!(s),
            );
          },
        );
      },
    );
  }

  String _message(Object err) {
    final msg = err.toString();
    return msg.startsWith('ApiException')
        ? "Couldn't load suggestions. Check your connection and retry."
        : msg.replaceFirst('Exception: ', '');
  }
}
