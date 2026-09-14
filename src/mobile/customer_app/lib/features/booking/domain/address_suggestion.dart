import 'package:freezed_annotation/freezed_annotation.dart';

part 'address_suggestion.freezed.dart';
part 'address_suggestion.g.dart';

/// One autocomplete result from `POST /api/v2/address/search`. Holds just
/// enough to render a row and resolve to a full [Place] on selection.
@freezed
abstract class AddressSuggestion with _$AddressSuggestion {
  const factory AddressSuggestion({
    required String placeId,
    @Default('') String description,
    @Default('') String mainText,
    @Default('') String secondaryText,
    String? postcode,
  }) = _AddressSuggestion;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      _$AddressSuggestionFromJson(json);
}
