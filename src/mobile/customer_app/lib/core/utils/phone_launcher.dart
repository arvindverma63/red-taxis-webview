import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dials [phone] via the platform dialler (`tel:` URI). Returns true when the
/// dialler opened. When [phone] is empty (no office number configured) or the
/// launch fails, shows a SnackBar fallback so the user still knows what to do
/// rather than tapping into nothing.
///
/// Centralised here so every "Call office" affordance (quote-failure fallback,
/// booking-sent screen) behaves identically and we only depend on
/// `url_launcher` in one place.
Future<bool> callOffice(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final trimmed = phone.trim();

  if (trimmed.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Please call the office to complete your booking.'),
        ),
      );
    return false;
  }

  final uri = Uri(scheme: 'tel', path: trimmed);
  try {
    final launched = await launchUrl(uri);
    if (!launched) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Call the office on $trimmed.')));
    }
    return launched;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Call the office on $trimmed.')));
    return false;
  }
}

/// Calls the assigned driver on [phone]. Shows a clear message when the driver's
/// number isn't available or the dialler can't open.
Future<bool> callDriver(BuildContext context, String? phone, String name) =>
    _contactDriver(context, phone, name, 'tel', 'Call');

/// Opens a text message to the assigned driver on [phone].
Future<bool> messageDriver(BuildContext context, String? phone, String name) =>
    _contactDriver(context, phone, name, 'sms', 'Message');

Future<bool> _contactDriver(
  BuildContext context,
  String? phone,
  String name,
  String scheme,
  String verb,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final number = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');

  void tell(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  if (number.isEmpty) {
    tell(
      "$name's phone number isn't available yet. Please contact the office.",
    );
    return false;
  }
  try {
    final launched = await launchUrl(Uri(scheme: scheme, path: number));
    if (!launched) tell('$verb $name on $number.');
    return launched;
  } catch (_) {
    tell('$verb $name on $number.');
    return false;
  }
}
