import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../data/booking_repository.dart';
import '../domain/booking_draft.dart';
import '../domain/quote.dart';
import 'booking_draft_controller.dart';

/// Account number used for cash (public) pricing.
const String kCashAccountNo = '9999';

/// Fetches a fare quote for the current draft and writes it back onto the draft
/// (so downstream screens read price from one place). Exposes an [AsyncValue]
/// so the review screen can show loading / error / value states.
///
/// Refetch is explicit: the review screen calls [refresh] when the route,
/// vehicle, passenger count or schedule changes.
class QuoteController extends AsyncNotifier<Quote?> {
  @override
  Future<Quote?> build() async {
    // Surface any quote already on the draft (e.g. coming back from payment).
    return ref.read(bookingDraftProvider).quote;
  }

  /// Recomputes the quote from the current draft. No-op (clears to null) when
  /// the route is incomplete.
  Future<void> refresh() async {
    final draft = ref.read(bookingDraftProvider);
    if (!draft.hasRoute) {
      state = const AsyncData(null);
      return;
    }

    final pickupPostcode = draft.pickup?.postcode?.trim() ?? '';
    final destPostcode = draft.dropoff?.postcode?.trim() ?? '';
    if (pickupPostcode.isEmpty || destPostcode.isEmpty) {
      state = AsyncError(
        const _MissingPostcode(),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(bookingRepositoryProvider);
      final accountNo = _accountNoForDraft(draft);
      final quote = await repo.getQuote(
        accountNo: accountNo,
        pickupDateTime: draft.scheduledFor ?? DateTime.now(),
        passengers: draft.passengers,
        pickupPostcode: pickupPostcode,
        destinationPostcode: destPostcode,
        viaPostcodes: draft.vias
            .map((p) => p.postcode?.trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
      // Mirror onto the draft so payment/confirm read a single source.
      ref.read(bookingDraftProvider.notifier).setQuote(quote);
      return quote;
    });
  }

  /// Account users quote against their own account number; everyone else (and
  /// account users paying cash/card) quotes against the cash account.
  String _accountNoForDraft(BookingDraft draft) {
    final user = ref.read(currentUserProvider);
    final billingToAccount =
        draft.paymentMethod == 'account' && (user?.isAccount ?? false);
    if (billingToAccount) {
      // Account number is the username for account-type users.
      final acc = user?.username.trim();
      if (acc != null && acc.isNotEmpty) return acc;
    }
    return kCashAccountNo;
  }
}

final quoteControllerProvider =
    AsyncNotifierProvider<QuoteController, Quote?>(QuoteController.new);

/// Raised when a resolved place is missing a postcode (quote needs both ends).
class _MissingPostcode implements Exception {
  const _MissingPostcode();
  @override
  String toString() =>
      "We couldn't price this route — one of the addresses has no postcode. "
      'Try picking a more specific address.';
}
