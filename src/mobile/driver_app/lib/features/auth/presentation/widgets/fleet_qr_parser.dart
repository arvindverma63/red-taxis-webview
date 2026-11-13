import 'dart:convert';

/// Why a scanned or imported code was not accepted as a fleet activation code.
enum FleetQrFailure {
  /// The image contained no readable QR code.
  noCodeFound,

  /// A QR code was read, but it is not a fleet activation code (a website,
  /// Wi-Fi code, plain text, ...).
  unsupported,

  /// It looks like a fleet code but the fleet ID is malformed.
  invalid,
}

class FleetQrResult {
  const FleetQrResult.ok(this.payload) : failure = null;
  const FleetQrResult.fail(this.failure) : payload = null;

  final Map<String, String>? payload;
  final FleetQrFailure? failure;

  bool get isOk => payload != null;

  /// User-facing explanation for a failed result.
  String get message {
    switch (failure) {
      case FleetQrFailure.noCodeFound:
        return 'No QR code found in that image. Choose a clear image of your fleet activation QR code.';
      case FleetQrFailure.unsupported:
        return 'This QR code is not a fleet activation code. Ask your fleet manager for the correct code.';
      case FleetQrFailure.invalid:
        return 'This fleet activation code is invalid or damaged. Ask your fleet manager for a new one.';
      case null:
        return '';
    }
  }
}

/// Fleet IDs look like `org_…` / `fleet_…`.
final _tenantIdPattern = RegExp(r'^(org|fleet)_[A-Za-z0-9_\-]{2,}$');

/// Parses the text of a fleet activation QR code. Supports JSON, deep-link /
/// URL query parameters, `id:key[:name]` / `id|key[|name]`, and a bare fleet ID.
FleetQrResult parseFleetQr(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty) return const FleetQrResult.fail(FleetQrFailure.unsupported);

  String? tenantId;
  String? tenantKey;
  String? companyName;
  String? primaryColour;

  if (clean.startsWith('{') && clean.endsWith('}')) {
    try {
      final data = jsonDecode(clean);
      if (data is Map) {
        String? pick(List<String> keys) {
          for (final k in keys) {
            final v = data[k]?.toString();
            if (v != null && v.isNotEmpty) return v;
          }
          return null;
        }

        tenantId = pick(['tenantId', 'id', 'fleetId']);
        tenantKey = pick(['tenantKey', 'key', 'apiKey']);
        companyName = pick(['companyName', 'name', 'brand']);
        primaryColour = pick(['primaryColour', 'primaryColor', 'color']);
      }
    } catch (_) {}
  } else if (clean.contains('://') || clean.contains('tenantId=')) {
    final uri = Uri.tryParse(clean);
    if (uri == null) return const FleetQrResult.fail(FleetQrFailure.unsupported);
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = uri.queryParameters[k];
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    tenantId = pick(['tenantId', 'id', 'tenant']);
    tenantKey = pick(['tenantKey', 'key', 'token']);
    companyName = pick(['companyName', 'name', 'fleet']);
    primaryColour = pick(['primaryColour', 'primaryColor', 'color']);
  } else if (clean.contains(':') || clean.contains('|')) {
    final parts = clean.split(clean.contains('|') ? '|' : ':');
    if (parts.length >= 2) {
      tenantId = parts[0].trim();
      tenantKey = parts[1].trim();
      if (parts.length >= 3 && parts[2].trim().isNotEmpty) {
        companyName = parts[2].trim();
      }
    }
  } else {
    tenantId = clean;
  }

  if (tenantId == null || tenantId.isEmpty) {
    return const FleetQrResult.fail(FleetQrFailure.unsupported);
  }
  // Something that is clearly not a fleet code (plain text, a URL without a
  // fleet ID) is "unsupported"; a fleet-looking ID that is malformed is
  // "invalid".
  if (!_tenantIdPattern.hasMatch(tenantId)) {
    final looksLikeFleet =
        tenantId.startsWith('org_') || tenantId.startsWith('fleet_');
    return FleetQrResult.fail(
      looksLikeFleet ? FleetQrFailure.invalid : FleetQrFailure.unsupported,
    );
  }

  return FleetQrResult.ok({
    'tenantId': tenantId,
    'tenantKey': tenantKey ?? '',
    if (companyName != null) 'companyName': companyName,
    if (primaryColour != null) 'primaryColour': primaryColour,
  });
}

/// Cleans a Tenant ID / access key typed or pasted by hand.
///
/// Drivers often paste the pair as one value (`org_123:rtk_pub_abc`, or with a
/// space / `|` / comma between), or with quotes around it. Left alone, that
/// whole string becomes the "Tenant ID", the key stays empty and the server
/// rejects it. This splits such input into the real ID and key, and strips
/// quotes and stray whitespace. Anything else is returned trimmed.
({String tenantId, String tenantKey}) normalizeTenantCredentials(
  String rawId,
  String rawKey,
) {
  String clean(String s) => s
      .trim()
      .replaceAll(RegExp('^[\'"“”‘’`]+|[\'"“”‘’`]+\$'), '')
      .trim();

  final separators = RegExp(r'[:|,;\s]');
  var id = clean(rawId);
  var key = clean(rawKey);

  if (separators.hasMatch(id)) {
    final joined = id.replaceAll(RegExp(r'[:|,;\s]+'), ':');
    final parsed = parseFleetQr(joined);
    if (parsed.isOk) {
      id = parsed.payload!['tenantId']!;
      final fromPair = parsed.payload!['tenantKey'] ?? '';
      if (key.isEmpty && fromPair.isNotEmpty) key = fromPair;
    } else {
      id = id.split(separators).firstWhere((p) => p.isNotEmpty, orElse: () => id);
    }
  }

  // The same pair pasted into the key field: "org_123:rtk_pub_abc".
  if (separators.hasMatch(key)) {
    final joined = key.replaceAll(RegExp(r'[:|,;\s]+'), ':');
    final parsed = parseFleetQr(joined);
    if (parsed.isOk && parsed.payload!['tenantKey']!.isNotEmpty) {
      if (id.isEmpty) id = parsed.payload!['tenantId']!;
      key = parsed.payload!['tenantKey']!;
    } else {
      key = key.split(separators).firstWhere((p) => p.isNotEmpty, orElse: () => key);
    }
  }

  return (tenantId: id, tenantKey: key);
}
