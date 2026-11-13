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

  /// Secondary / background tint from the tenant (`secondaryHsl`). Used as the
  /// light-mode page background when it is light enough to keep text readable.
  final Color secondaryColor;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final String? dispatchPhone;
  final String? supportEmail;

  /// When the branding was last refreshed from `/public/tenant-info`.
  final DateTime? syncedAt;

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
    this.secondaryColor = const Color(0xFFF8F9FA),
    this.gradientStart = const Color(0xFFCD1A21),
    this.gradientMid = const Color(0xFF9E0E14),
    this.gradientEnd = const Color(0xFF6B0509),
    this.dispatchPhone,
    this.supportEmail,
    this.syncedAt,
  });

  factory TenantBranding.defaultFirstTaxis() {
    return const TenantBranding(
      tenantId: 'org_ace_taxis',
      tenantKey: 'tk_live_ace_staging_2026',
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
    Color? secondaryColor,
    Color? gradientStart,
    Color? gradientMid,
    Color? gradientEnd,
    String? dispatchPhone,
    String? supportEmail,
    DateTime? syncedAt,
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
      secondaryColor: secondaryColor ?? this.secondaryColor,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      dispatchPhone: dispatchPhone ?? this.dispatchPhone,
      supportEmail: supportEmail ?? this.supportEmail,
      syncedAt: syncedAt ?? this.syncedAt,
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

  /// First value that is a non-blank string (the API sends "" for unset).
  static String? _firstNonBlank(Iterable<dynamic> values) {
    for (final v in values) {
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  static final RegExp _hslPattern = RegExp(
    r'^\s*(?:hsla?\()?\s*(-?\d+(?:\.\d+)?)(?:deg)?[\s,]+(\d+(?:\.\d+)?)%?[\s,]+'
    r'(\d+(?:\.\d+)?)%?\s*(?:[,/]\s*[\d.]+%?\s*)?\)?\s*$',
    caseSensitive: false,
  );

  /// Parses CSS-style HSL as the tenant API sends it: `"200 98% 39%"`, also
  /// `"200, 98%, 39%"`, `"hsl(200 98% 39%)"` and `"hsl(200, 98%, 39%)"`.
  /// Returns null for anything else.
  static Color? parseHsl(dynamic value) {
    if (value is! String) return null;
    final m = _hslPattern.firstMatch(value);
    if (m == null) return null;
    final h = double.tryParse(m.group(1)!);
    final s = double.tryParse(m.group(2)!);
    final l = double.tryParse(m.group(3)!);
    if (h == null || s == null || l == null) return null;
    return HSLColor.fromAHSL(
      1.0,
      ((h % 360) + 360) % 360,
      (s / 100).clamp(0.0, 1.0),
      (l / 100).clamp(0.0, 1.0),
    ).toColor();
  }

  /// Hex colour if one is set, otherwise the HSL value, otherwise [fallback].
  static Color _hexOrHsl(
    Iterable<dynamic> hexCandidates,
    Iterable<dynamic> hslCandidates,
    Color fallback,
  ) {
    final hex = _firstNonBlank(hexCandidates);
    if (hex != null) {
      final parsed = _parseColor(hex, const Color(0x00000000));
      if (parsed != const Color(0x00000000)) return parsed;
    }
    final hsl = _firstNonBlank(hslCandidates);
    return parseHsl(hsl) ?? fallback;
  }

  /// True when [payload] carries any usable brand colour (hex or HSL).
  static bool payloadHasColours(Map<String, dynamic> payload) {
    final nested = payload['branding'] is Map<String, dynamic>
        ? payload['branding'] as Map<String, dynamic>
        : payload;
    final colors = nested['colors'] is Map<String, dynamic>
        ? nested['colors'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return _firstNonBlank([
          colors['primary'],
          payload['primaryColour'],
          payload['primaryColor'],
          payload['primaryHsl'],
          colors['primaryHsl'],
        ]) !=
        null;
  }

  /// Turns a logo address from the API into a full web address: keeps
  /// `http(s)://` URLs, adds `https:` to `//host/…`, and joins `/path` or
  /// `path` onto [baseUrl]. Returns null for blank values.
  static String? absoluteUrl(String? raw, String baseUrl) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return t;
    if (t.startsWith('//')) return 'https:$t';
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return t.startsWith('/') ? '$base$t' : '$base/$t';
  }

  /// A copy whose logo addresses are full web addresses (see [absoluteUrl]).
  TenantBranding withAbsoluteLogos(String baseUrl) {
    return TenantBranding(
      tenantId: tenantId,
      tenantKey: tenantKey,
      name: name,
      legalName: legalName,
      logoLightUrl: absoluteUrl(logoLightUrl, baseUrl),
      logoDarkUrl: absoluteUrl(logoDarkUrl, baseUrl),
      symbolUrl: absoluteUrl(symbolUrl, baseUrl),
      primaryColor: primaryColor,
      primaryDarkColor: primaryDarkColor,
      primaryLightColor: primaryLightColor,
      accentColor: accentColor,
      secondaryColor: secondaryColor,
      gradientStart: gradientStart,
      gradientMid: gradientMid,
      gradientEnd: gradientEnd,
      dispatchPhone: dispatchPhone,
      supportEmail: supportEmail,
      syncedAt: syncedAt,
    );
  }

  /// The fleet colours as CSS custom properties for the web pages shown inside
  /// the app (`var(--brand-primary)` etc.). `--brand-primary-rgb` allows
  /// translucent tints: `rgba(var(--brand-primary-rgb), 0.12)`.
  Map<String, String> toCssVariables() {
    String hex(Color c) => _colorToHex(c).toLowerCase();
    int ch(double v) => (v * 255).round().clamp(0, 255);
    final p = primaryColor;
    return {
      '--brand-primary': hex(p),
      '--brand-primary-rgb': '${ch(p.r)}, ${ch(p.g)}, ${ch(p.b)}',
      '--brand-primary-dark': hex(primaryDarkColor),
      '--brand-primary-light': hex(primaryLightColor),
      '--brand-on-primary': hex(onPrimaryColor),
      '--brand-secondary': hex(secondaryColor),
      // Page background: the secondary colour when it is light enough for dark
      // text, otherwise the standard light grey.
      '--brand-background': HSLColor.fromColor(secondaryColor).lightness >= 0.80
          ? hex(secondaryColor)
          : '#f8f9fa',
      // Names the website already used before the brand variables existed.
      '--primary-color': hex(p),
      '--primary-dark': hex(primaryDarkColor),
    };
  }

  /// Colour used for text/icons placed on the primary colour.
  Color get onPrimaryColor =>
      ThemeData.estimateBrightnessForColor(primaryColor) == Brightness.dark
          ? Colors.white
          : const Color(0xFF111827);

  /// Same look (name, colours, logos, contacts) ignoring sync timestamps.
  bool sameLookAs(TenantBranding o) =>
      name == o.name &&
      primaryColor == o.primaryColor &&
      primaryDarkColor == o.primaryDarkColor &&
      primaryLightColor == o.primaryLightColor &&
      accentColor == o.accentColor &&
      secondaryColor == o.secondaryColor &&
      logoLightUrl == o.logoLightUrl &&
      logoDarkUrl == o.logoDarkUrl &&
      symbolUrl == o.symbolUrl &&
      dispatchPhone == o.dispatchPhone &&
      supportEmail == o.supportEmail;

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

    // The tenant API sends colours as HSL (`primaryHsl` "200 98% 39%") and
    // leaves `primaryColour` as "" — a blank hex must not win over the HSL.
    final primaryParsed = _hexOrHsl(
      [colors['primary'], json['primaryColour'], json['primaryColor'], rawJson['primaryColour'], rawJson['primaryColor']],
      [colors['primaryHsl'], json['primaryHsl'], rawJson['primaryHsl']],
      const Color(0xFFD32F2F),
    );
    final secondaryParsed = _hexOrHsl(
      [colors['secondary'], json['secondaryColour'], json['secondaryColor'], rawJson['secondaryColour'], rawJson['secondaryColor']],
      [colors['secondaryHsl'], json['secondaryHsl'], rawJson['secondaryHsl']],
      const Color(0xFFF8F9FA),
    );

    return TenantBranding(
      tenantId: tenantId,
      tenantKey: tenantKey,
      name: companyName,
      legalName: json['legalName']?.toString() ?? json['companyName']?.toString() ?? companyName,
      logoLightUrl: _firstNonBlank([logos['lightUrl'], json['logoLightUrl'], json['logoUrl'], rawJson['logoUrl']]),
      logoDarkUrl: _firstNonBlank([logos['darkUrl'], json['logoDarkUrl'], json['logoUrl'], rawJson['logoUrl']]),
      symbolUrl: _firstNonBlank([logos['symbolUrl'], json['symbolUrl']]),
      primaryColor: primaryParsed,
      primaryDarkColor: _parseColor(colors['primaryDark'] ?? json['primaryDarkColor'], _darkenColor(primaryParsed, 0.18)),
      primaryLightColor: _parseColor(colors['primaryLight'] ?? json['primaryLightColor'], _lightenColor(primaryParsed, 0.18)),
      accentColor: _parseColor(colors['accent'] ?? json['accentColor'], const Color(0xFFFFA000)),
      secondaryColor: secondaryParsed,
      gradientStart: _parseColor(colors['gradientStart'] ?? json['gradientStart'], primaryParsed),
      gradientMid: _parseColor(colors['gradientMid'] ?? json['gradientMid'], _darkenColor(primaryParsed, 0.12)),
      gradientEnd: _parseColor(colors['gradientEnd'] ?? json['gradientEnd'], _darkenColor(primaryParsed, 0.28)),
      dispatchPhone: support['dispatchPhone']?.toString() ?? json['dispatchPhone']?.toString() ?? json['phone']?.toString() ?? rawJson['phone']?.toString(),
      supportEmail: support['supportEmail']?.toString() ?? json['supportEmail']?.toString() ?? json['email']?.toString() ?? rawJson['email']?.toString(),
      syncedAt: DateTime.tryParse(rawJson['syncedAt']?.toString() ?? json['syncedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenantId': tenantId,
      'tenantKey': tenantKey,
      'name': name,
      'legalName': legalName,
      'syncedAt': syncedAt?.toIso8601String(),
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
          'secondary': _colorToHex(secondaryColor),
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

  /// The tenant's secondary colour is used as the page background in light
  /// mode, but only when it is light enough for dark text to stay readable.
  static Color _lightBackgroundFor(TenantBranding branding) {
    final l = HSLColor.fromColor(branding.secondaryColor).lightness;
    return l >= 0.80 ? branding.secondaryColor : lightBackground;
  }

  static ThemeData getDynamicLightTheme(TenantBranding branding) {
    final primary = branding.primaryColor;
    final primaryDark = branding.primaryDarkColor;
    final onPrimary = branding.onPrimaryColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: _lightBackgroundFor(branding),
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primaryDark,
        secondaryContainer: branding.secondaryColor,
        onSecondaryContainer: textLightPrimary,
        surface: lightSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: onPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 52),
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
    final onPrimary = branding.onPrimaryColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primaryDark,
        secondaryContainer: Color.alphaBlend(
          branding.secondaryColor.withValues(alpha: 0.16),
          darkSurface,
        ),
        onSecondaryContainer: textDarkPrimary,
        surface: darkSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: onPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 52),
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

enum FontSizeOption {
  standard(1.0, 'Standard', 'Default (100%)', 'A'),
  large(1.15, 'Large', 'Comfortable (115%)', 'A+'),
  extraLarge(1.30, 'Extra Large', 'Senior Friendly (130%)', 'A++');

  final double scale;
  final String label;
  final String description;
  final String badge;

  const FontSizeOption(this.scale, this.label, this.description, this.badge);

  static FontSizeOption fromScale(double scale) {
    if (scale >= 1.25) return FontSizeOption.extraLarge;
    if (scale >= 1.10) return FontSizeOption.large;
    return FontSizeOption.standard;
  }
}

final fontSizeScaleProvider = StateNotifierProvider<FontSizeScaleNotifier, FontSizeOption>((ref) {
  return FontSizeScaleNotifier();
});

class FontSizeScaleNotifier extends StateNotifier<FontSizeOption> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  FontSizeScaleNotifier() : super(FontSizeOption.standard) {
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    try {
      final saved = await _storage.read(key: 'font_scale_option');
      if (saved != null) {
        final scale = double.tryParse(saved);
        if (scale != null) {
          state = FontSizeOption.fromScale(scale);
        } else if (saved == 'extraLarge') {
          state = FontSizeOption.extraLarge;
        } else if (saved == 'large') {
          state = FontSizeOption.large;
        } else {
          state = FontSizeOption.standard;
        }
      }
    } catch (_) {}
  }

  Future<void> setFontSize(FontSizeOption option) async {
    state = option;
    try {
      await _storage.write(key: 'font_scale_option', value: option.scale.toString());
    } catch (_) {}
  }
}

