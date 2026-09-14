/// Barrel for booking-feature-local widgets built to match the GoRide Figma
/// kit (file key `sNibZIAuIW0DYLVNNfX7z2`). These live here — not in
/// `core/widgets` — because parallel agents are editing the repo; promote any
/// that prove reusable beyond booking.
///
/// Promotion candidates (GoRide-generic, not booking-specific):
/// - [PillChip] — outlined shortcut pill (Home/Office/Select from map).
/// - [SegmentedToggle] — Recent/Suggested two-segment control.
/// - [CircleIconButton] — floating circular map / accent buttons.
library;

export 'circle_icon_button.dart';
export 'info_note.dart';
export 'location_search_card.dart';
export 'map_pin_confirm_card.dart';
export 'payment_method_row.dart';
export 'pill_chip.dart';
export 'place_result_row.dart';
export 'quote_unavailable_card.dart';
export 'segmented_toggle.dart';
