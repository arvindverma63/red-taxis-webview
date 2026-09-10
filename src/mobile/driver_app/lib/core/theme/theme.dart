import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:driver_app/core/config/constants.dart';

class TenantBranding {
  final String tenantId;
  final String tenantKey;
  final String name;
  final String legalName;
  final String? logoLightUrl;
  final String? logoDarkUrl;
  final String? symbolUrl;
  final Color primaryColor;
  final Color primaryDarkColor;
  final Color primaryLightColor;
  final Color accentColor;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final String? dispatchPhone;
  final String? supportEmail;

  const TenantBranding({
    required this.tenantId,
    required this.tenantKey,
    required this.name,
    this.legalName = '',
    this.logoLightUrl,
    this.logoDarkUrl,
    this.symbolUrl,
    this.primaryColor = const Color(0xFFCD1A21),
    this.primaryDarkColor = const Color(0xFF9E0E14),
    this.primaryLightColor = const Color(0xFFFF5252),
    this.accentColor = const Color(0xFFF59E0B),
    this.gradientStart = const Color(0xFFCD1A21),
    this.gradientMid = const Color(0xFF9E0E14),
    this.gradientEnd = const Color(0xFF6B0509),
    this.dispatchPhone,
    this.supportEmail,
  });

  factory TenantBranding.defaultFirstTaxis() {
    return const TenantBranding(
      tenantId: 'org_first_taxis',
      tenantKey: 'tk_live_8f93c72b10a94e82b7',
      name: 'First Taxis',
      legalName: 'First Taxis Group Ltd',
      primaryColor: Color(0xFFCD1A21),
      primaryDarkColor: Color(0xFF9E0E14),
      primaryLightColor: Color(0xFFFF5252),
      accentColor: Color(0xFFF59E0B),
      gradientStart: Color(0xFFCD1A21),
      gradientMid: Color(0xFF9E0E14),
      gradientEnd: Color(0xFF6B0509),
      dispatchPhone: '+441234567890',
      supportEmail: 'drivers@firsttaxis.co.uk',
    );
  }

  factory TenantBranding.defaultAceTaxis() {
    return const TenantBranding(
      tenantId: 'org_ace_taxis',
      tenantKey: 'tk_live_ace_staging_2026',
      name: 'Ace Taxis',
      legalName: 'Ace Taxis UK Ltd',
      primaryColor: Color(0xFFE53935),
      primaryDarkColor: Color(0xFFB71C1C),
      primaryLightColor: Color(0xFFFF6F60),
      accentColor: Color(0xFFFFB300),
      gradientStart: Color(0xFFE53935),
      gradientMid: Color(0xFFC62828),
      gradientEnd: Color(0xFF8E0000),
      dispatchPhone: '+441234567899',
      supportEmail: 'support@acetaxis.co.uk',
    );
  }

  factory TenantBranding.defaultRedTaxis() {
    return const TenantBranding(
      tenantId: 'org_red_taxis',
      tenantKey: 'tk_live_red_taxis_dev',
      name: 'Red Taxis',
      legalName: 'Red Taxis Transport Group',
      primaryColor: Color(0xFFD32F2F),
      primaryDarkColor: Color(0xFF8B0000),
      primaryLightColor: Color(0xFFFF6659),
      accentColor: Color(0xFFFFA000),
      gradientStart: Color(0xFFD32F2F),
      gradientMid: Color(0xFFB71C1C),
      gradientEnd: Color(0xFF5D0000),
      dispatchPhone: '+441234567800',
      supportEmail: 'drivers@redtaxis.co.uk',
    );
  }

  TenantBranding copyWith({
    String? tenantId,
    String? tenantKey,
    String? name,
    String? legalName,
    String? logoLightUrl,
    String? logoDarkUrl,
    String? symbolUrl,
    Color? primaryColor,
    Color? primaryDarkColor,
    Color? primaryLightColor,
    Color? accentColor,
    Color? gradientStart,
    Color? gradientMid,
    Color? gradientEnd,
    String? dispatchPhone,
    String? supportEmail,
  }) {
    return TenantBranding(
      tenantId: tenantId ?? this.tenantId,
      tenantKey: tenantKey ?? this.tenantKey,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      logoLightUrl: logoLightUrl ?? this.logoLightUrl,
      logoDarkUrl: logoDarkUrl ?? this.logoDarkUrl,
      symbolUrl: symbolUrl ?? this.symbolUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      primaryDarkColor: primaryDarkColor ?? this.primaryDarkColor,
      primaryLightColor: primaryLightColor ?? this.primaryLightColor,
      accentColor: accentColor ?? this.accentColor,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      dispatchPhone: dispatchPhone ?? this.dispatchPhone,
      supportEmail: supportEmail ?? this.supportEmail,
    );
  }

  static Color _darkenColor(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  static Color _lightenColor(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  static Color _parseColor(dynamic hex, Color fallback) {
    if (hex == null || hex is! String || hex.trim().isEmpty) return fallback;
    try {
      String clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String get primaryHex => _colorToHex(primaryColor);
  String get primaryDarkHex => _colorToHex(primaryDarkColor);

  factory TenantBranding.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['data'] is Map<String, dynamic>
        ? rawJson['data'] as Map<String, dynamic>
        : (rawJson['branding'] is Map<String, dynamic> ? rawJson['branding'] as Map<String, dynamic> : rawJson);

    final branding = json['branding'] is Map<String, dynamic> ? json['branding'] as Map<String, dynamic> : json;
    final colors = branding['colors'] is Map<String, dynamic> ? branding['colors'] as Map<String, dynamic> : {};
    final logos = branding['logos'] is Map<String, dynamic> ? branding['logos'] as Map<String, dynamic> : {};
    final support = branding['support'] is Map<String, dynamic> ? branding['support'] as Map<String, dynamic> : {};

    final tenantId = json['tenantId']?.toString() ?? json['id']?.toString() ?? rawJson['tenantId']?.toString() ?? 'org_red_taxis';
    final tenantKey = json['tenantKey']?.toString() ?? rawJson['tenantKey']?.toString() ?? '';
    final companyName = json['companyName']?.toString() ??
        json['name']?.toString() ??
        json['displayName']?.toString() ??
        rawJson['companyName']?.toString() ??
        rawJson['name']?.toString() ??
        'Red Taxis';

    final primaryParsed = _parseColor(
      colors['primary'] ?? json['primaryColour'] ?? json['primaryColor'] ?? rawJson['primaryColour'] ?? rawJson['primaryColor'],
      const Color(0xFFD32F2F),
    );

    return TenantBranding(
      tenantId: tenantId,
      tenantKey: tenantKey,
      name: companyName,
      legalName: json['legalName']?.toString() ?? json['companyName']?.toString() ?? companyName,
      logoLightUrl: logos['lightUrl']?.toString() ?? json['logoLightUrl']?.toString() ?? json['logoUrl']?.toString() ?? rawJson['logoUrl']?.toString(),
      logoDarkUrl: logos['darkUrl']?.toString() ?? json['logoDarkUrl']?.toString() ?? json['logoUrl']?.toString(),
      symbolUrl: logos['symbolUrl']?.toString() ?? json['symbolUrl']?.toString(),
      primaryColor: primaryParsed,
      primaryDarkColor: _parseColor(colors['primaryDark'] ?? json['primaryDarkColor'], _darkenColor(primaryParsed, 0.18)),
      primaryLightColor: _parseColor(colors['primaryLight'] ?? json['primaryLightColor'], _lightenColor(primaryParsed, 0.18)),
      accentColor: _parseColor(colors['accent'] ?? json['accentColor'], const Color(0xFFFFA000)),
      gradientStart: _parseColor(colors['gradientStart'] ?? json['gradientStart'], primaryParsed),
      gradientMid: _parseColor(colors['gradientMid'] ?? json['gradientMid'], _darkenColor(primaryParsed, 0.12)),
      gradientEnd: _parseColor(colors['gradientEnd'] ?? json['gradientEnd'], _darkenColor(primaryParsed, 0.28)),
      dispatchPhone: support['dispatchPhone']?.toString() ?? json['dispatchPhone']?.toString() ?? json['phone']?.toString() ?? rawJson['phone']?.toString(),
      supportEmail: support['supportEmail']?.toString() ?? json['supportEmail']?.toString() ?? json['email']?.toString() ?? rawJson['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenantId': tenantId,
      'tenantKey': tenantKey,
      'name': name,
      'legalName': legalName,
      'branding': {
        'logos': {
          'lightUrl': logoLightUrl,
          'darkUrl': logoDarkUrl,
          'symbolUrl': symbolUrl,
        },
        'colors': {
          'primary': primaryHex,
          'primaryDark': primaryDarkHex,
          'primaryLight': _colorToHex(primaryLightColor),
          'accent': _colorToHex(accentColor),
          'gradientStart': _colorToHex(gradientStart),
          'gradientMid': _colorToHex(gradientMid),
          'gradientEnd': _colorToHex(gradientEnd),
        },
        'support': {
          'dispatchPhone': dispatchPhone,
          'supportEmail': supportEmail,
        },
      },
    };
  }
}

class AppTheme {
  // Brand color palette (defaults)
  static const Color primaryRed = Color(0xFFCD1A21);
  static const Color primaryDarkRed = Color(0xFF9E0E14);
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1E1E24);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color textDarkPrimary = Color(0xFFECEFF1);
  static const Color textDarkSecondary = Color(0xFF90A4AE);
  static const Color textLightPrimary = Color(0xFF263238);
  static const Color textLightSecondary = Color(0xFF546E7A);

  static ThemeData get lightTheme => getDynamicLightTheme(TenantBranding.defaultFirstTaxis());
  static ThemeData get darkTheme => getDynamicDarkTheme(TenantBranding.defaultFirstTaxis());

  static ThemeData getDynamicLightTheme(TenantBranding branding) {
    final primary = branding.primaryColor;
    final primaryDark = branding.primaryDarkColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        surface: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textLightPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: textLightSecondary, size: 22),
        titleTextStyle: TextStyle(
          color: textLightPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static ThemeData getDynamicDarkTheme(TenantBranding branding) {
    final primary = branding.primaryColor;
    final primaryDark = branding.primaryDarkColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDarkPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: textDarkSecondary, size: 22),
        titleTextStyle: TextStyle(
          color: textDarkPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final mode = await _storage.read(key: 'theme_mode');
      if (mode == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.light;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    try {
      await _storage.write(key: 'theme_mode', value: isDarkMode ? 'dark' : 'light');
    } catch (_) {}
  }
}

final tenantBrandingProvider = StateNotifierProvider<TenantBrandingNotifier, TenantBranding>((ref) {
  return TenantBrandingNotifier();
});

class TenantBrandingNotifier extends StateNotifier<TenantBranding> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  TenantBrandingNotifier() : super(TenantBranding.defaultRedTaxis()) {
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final brandingJsonStr = await _storage.read(key: AppConfig.keyTenantBranding);
      if (brandingJsonStr != null && brandingJsonStr.isNotEmpty) {
        final decoded = jsonDecode(brandingJsonStr);
        if (decoded is Map<String, dynamic>) {
          state = TenantBranding.fromJson(decoded);
        }
      }
    } catch (_) {}
  }

  void updateBranding(TenantBranding branding) {
    state = branding;
    try {
      _storage.write(
        key: AppConfig.keyTenantBranding,
        value: jsonEncode(branding.toJson()),
      );
    } catch (_) {}
  }
}
