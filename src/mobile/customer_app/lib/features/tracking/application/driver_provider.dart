import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/driver_directory.dart';
import '../../../core/domain/driver_fields.dart';
import '../data/tracking_repository.dart';

/// The assigned driver's details for a booking, loaded from
/// `GET /api/v2/customers/me/bookings/{id}/driver`. Null while no driver is
/// assigned or when the lookup fails; also fills the [DriverDirectory] so every
/// screen shows the same driver.
final bookingDriverProvider = FutureProvider.family<DriverFields?, String>((
  ref,
  bookingId,
) async {
  await ref.read(trackingRepositoryProvider).fetchDriverDetails(bookingId);
  return DriverDirectory.of(bookingId);
});
