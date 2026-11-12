import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/booking_repository.dart';
import '../domain/address_suggestion.dart';

/// Autocomplete suggestions for a query string. The screen debounces input and
/// updates [addressQueryProvider]; this family fetches whenever the (trimmed)
/// query changes. An empty/too-short query short-circuits to no results so we
/// never spend a billable autocomplete call on a single keystroke.
/// Minimum characters before an autocomplete call is made.
const kMinAddressQueryLength = 4;

final addressSuggestionsProvider =
    FutureProvider.autoDispose.family<List<AddressSuggestion>, String>(
  (ref, query) async {
    final trimmed = query.trim();
    if (trimmed.length < kMinAddressQueryLength) return const [];
    final repo = ref.watch(bookingRepositoryProvider);
    return repo.searchAddress(trimmed);
  },
);

/// The current search box text, set (debounced) by the address search screen.
final addressQueryProvider = StateProvider.autoDispose<String>((ref) => '');
