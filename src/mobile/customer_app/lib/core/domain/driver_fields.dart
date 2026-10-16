/// Tolerant extraction of assigned-driver details from a booking payload.
///
/// The backend variants (customer API, core booking API, push events) name these
/// fields differently and sometimes nest them in a `driver` object, so every
/// known spelling is accepted and nothing here ever throws.
class DriverFields {
  const DriverFields({
    this.name,
    this.phone,
    this.rating,
    this.photoUrl,
    this.plate,
    this.vehicleMake,
    this.vehicleColour,
  });

  final String? name;
  final String? phone;
  final double? rating;
  final String? photoUrl;
  final String? plate;
  final String? vehicleMake;
  final String? vehicleColour;

  bool get hasName => (name ?? '').trim().isNotEmpty;

  /// "Black Toyota Prius" style description from colour + make/model.
  String get vehicleDescription => [
    (vehicleColour ?? '').trim(),
    (vehicleMake ?? '').trim(),
  ].where((e) => e.isNotEmpty).join(' ');

  static String? _text(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null || v is Map || v is List) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty && t.toLowerCase() != 'null') return t;
    }
    return null;
  }

  static double? _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final n = double.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return null;
  }

  /// A copy where this record's missing values are filled from [other], and
  /// [other]'s non-empty values win otherwise (the newer response).
  DriverFields mergedWith(DriverFields other) {
    String? pick(String? mine, String? theirs) =>
        (theirs ?? '').trim().isNotEmpty ? theirs : mine;
    return DriverFields(
      name: pick(name, other.name),
      phone: pick(phone, other.phone),
      rating: other.rating ?? rating,
      photoUrl: pick(photoUrl, other.photoUrl),
      plate: pick(plate, other.plate),
      vehicleMake: pick(vehicleMake, other.vehicleMake),
      vehicleColour: pick(vehicleColour, other.vehicleColour),
    );
  }

  /// Reads driver details from [booking], looking inside a nested
  /// `driver` / `Driver` object first and then at flat `driverXxx` keys.
  factory DriverFields.from(Map<String, dynamic> booking) {
    Map<String, dynamic> nested = const {};
    final d = booking['driver'] ?? booking['Driver'];
    if (d is Map) nested = Map<String, dynamic>.from(d);

    String? pick(List<String> nestedKeys, List<String> flatKeys) =>
        _text(nested, nestedKeys) ?? _text(booking, flatKeys);

    final rating =
        _num(nested, const ['rating', 'Rating', 'averageRating']) ??
        _num(booking, const ['driverRating', 'DriverRating']);

    return DriverFields(
      name: pick(
        const ['name', 'fullName', 'fullname', 'FullName', 'displayName'],
        const ['driverName', 'driver_name', 'DriverName', 'driverFullName'],
      ),
      phone: pick(
        const [
          'phone',
          'phoneNumber',
          'mobile',
          'mobileNumber',
          'telephone',
          'Telephone',
          'contactNumber',
        ],
        const [
          'driverPhone',
          'driverPhoneNumber',
          'driverMobile',
          'driverTelephone',
          'DriverPhone',
          'driver_phone',
        ],
      ),
      rating: (rating != null && rating > 0 && rating <= 5) ? rating : null,
      photoUrl: pick(
        const ['photoUrl', 'imageUrl', 'avatar', 'avatarUrl', 'photo'],
        const ['driverPhotoUrl', 'driverImage', 'driverAvatar'],
      ),
      plate: pick(
        const [
          'plate',
          'vehicleReg',
          'VehicleReg',
          'regNumber',
          'registration',
        ],
        const [
          'vehicleReg',
          'VehicleReg',
          'plate',
          'registration',
          'regNumber',
        ],
      ),
      vehicleMake: pick(
        const ['vehicle', 'vehicleModel', 'VehicleModel', 'model', 'make'],
        const ['vehicleModel', 'VehicleModel', 'vehicleMake', 'vehicleName'],
      ),
      vehicleColour: pick(
        const ['vehicleColour', 'vehicleColor', 'colour', 'color'],
        const [
          'vehicleColour',
          'vehicleColor',
          'VehicleColour',
          'vehicle_colour',
        ],
      ),
    );
  }
}
