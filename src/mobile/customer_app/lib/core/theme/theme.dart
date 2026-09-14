import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../storage/storage_service.dart';

class TenantBranding {
  final String tenantId;
  final String name;
  final String legalName;
  final Color primaryColor;
  final Color primaryDark;
  final Color primaryLight;
  final Color secondaryColor;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final String? logoUrl;
  final String? logoDarkUrl;
  final String? symbolUrl;
  final String? dispatchPhone;
  final String? supportEmail;

  const TenantBranding({
    required this.tenantId,
    required this.name,
    required this.legalName,
    required this.primaryColor,
    required this.primaryDark,
    required this.primaryLight,
    required this.secondaryColor,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    this.logoUrl,
    this.logoDarkUrl,
    this.symbolUrl,
    this.dispatchPhone,
    this.supportEmail,
  });

  static TenantBranding defaultBranding() {
    const primary = Color(0xFFE50914);
    const dark = Color(0xFF8B0000);
    const light = Color(0xFFFF5252);
    return const TenantBranding(
      tenantId: AppConfig.defaultTenantId,
      name: 'Ace Taxis',
      legalName: 'Ace Taxis Private Hire Ltd',
      primaryColor: primary,
      primaryDark: dark,
      primaryLight: light,
      secondaryColor: Color(0xFF1E293B),
      gradientStart: primary,
      gradientMid: Color(0xFFB30710),
      gradientEnd: dark,
      dispatchPhone: '01234 567890',
      supportEmail: 'support@acetaxis.co.uk',
    );
  }

  factory TenantBranding.fromJson(Map<String, dynamic> json) {
    Color parseColor(dynamic hex, Color fallback) {
      if (hex == null) return fallback;
      try {
        final str = hex.toString().replaceAll('#', '').trim();
        if (str.length == 6) {
          return Color(int.parse('FF$str', radix: 16));
        } else if (str.length == 8) {
          return Color(int.parse(str, radix: 16));
        }
      } catch (_) {}
      return fallback;
    }

    final primary = parseColor(json['primaryColour'] ?? json['primaryColor'], const Color(0xFFE50914));
    
    // Auto calculate gradient derivations if not provided
    final hsl = HSLColor.fromColor(primary);
    final dark = parseColor(json['primaryDark'], hsl.withLightness((hsl.lightness - 0.25).clamp(0.0, 1.0)).toColor());
    final light = parseColor(json['primaryLight'], hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor());
    final mid = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    return TenantBranding(
      tenantId: json['tenantId'] ?? json['id'] ?? AppConfig.defaultTenantId,
      name: json['companyName'] ?? json['name'] ?? 'Red Taxi',
      legalName: json['legalName'] ?? json['companyName'] ?? 'Red Taxi Services Ltd',
      primaryColor: primary,
      primaryDark: dark,
      primaryLight: light,
      secondaryColor: parseColor(json['secondaryColor'], const Color(0xFF1E293B)),
      gradientStart: parseColor(json['gradientStart'], primary),
      gradientMid: parseColor(json['gradientMid'], mid),
      gradientEnd: parseColor(json['gradientEnd'], dark),
      logoUrl: json['logoUrl'] ?? json['logoLightUrl'],
      logoDarkUrl: json['logoDarkUrl'],
      symbolUrl: json['symbolUrl'] ?? json['iconUrl'],
      dispatchPhone: json['dispatchPhone'] ?? json['telephone'],
      supportEmail: json['supportEmail'] ?? json['email'],
    );
  }

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'companyName': name,
    'legalName': legalName,
    'primaryColour': '#${primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'primaryDark': '#${primaryDark.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'primaryLight': '#${primaryLight.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'secondaryColor': '#${secondaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'gradientStart': '#${gradientStart.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'gradientMid': '#${gradientMid.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'gradientEnd': '#${gradientEnd.value.toRadixString(16).padLeft(8, '0').substring(2)}',
    'logoUrl': logoUrl,
    'logoDarkUrl': logoDarkUrl,
    'symbolUrl': symbolUrl,
    'dispatchPhone': dispatchPhone,
    'supportEmail': supportEmail,
  };
}

class TenantBrandingNotifier extends StateNotifier<TenantBranding> {
  final StorageService _storage;

  TenantBrandingNotifier(this._storage) : super(TenantBranding.defaultBranding()) {
    _loadPersistedBranding();
  }

  Future<void> _loadPersistedBranding() async {
    try {
      final cached = await _storage.read(AppConfig.keyTenantBranding);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached);
        state = TenantBranding.fromJson(data);
      }
    } catch (_) {}
  }

  Future<void> setBranding(TenantBranding branding) async {
    state = branding;
    try {
      await _storage.write(AppConfig.keyTenantBranding, jsonEncode(branding.toJson()));
      await _storage.write(AppConfig.keyTenantId, branding.tenantId);
    } catch (_) {}
  }

  Future<void> resetToDefault() async {
    state = TenantBranding.defaultBranding();
    await _storage.delete(AppConfig.keyTenantBranding);
  }
}

final tenantBrandingProvider = StateNotifierProvider<TenantBrandingNotifier, TenantBranding>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TenantBrandingNotifier(storage);
});

// Theme Mode Notifier (Light/Dark/System)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _storage.read(AppConfig.keyThemeMode);
    if (mode == 'light') state = ThemeMode.light;
    if (mode == 'dark') state = ThemeMode.dark;
    if (mode == 'system') state = ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(AppConfig.keyThemeMode, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeModeNotifier(storage);
});

// Theme Factory
class AppTheme {
  static ThemeData lightTheme(TenantBranding branding) {
    final baseText = GoogleFonts.outfitTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: branding.primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.light(
        primary: branding.primaryColor,
        onPrimary: Colors.white,
        secondary: branding.secondaryColor,
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurface: const Color(0xFF0F172A),
        outline: const Color(0xFFE2E8F0),
      ),
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 15,
          color: const Color(0xFF334155),
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 13,
          color: const Color(0xFF64748B),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  static ThemeData darkTheme(TenantBranding branding) {
    final baseText = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: branding.primaryColor,
      scaffoldBackgroundColor: const Color(0xFF0B1120),
      colorScheme: ColorScheme.dark(
        primary: branding.primaryLight,
        onPrimary: Colors.white,
        secondary: const Color(0xFF94A3B8),
        surface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFF334155),
        onSurface: const Color(0xFFF8FAFC),
        outline: const Color(0xFF334155),
      ),
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC),
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC),
          letterSpacing: -0.3,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF8FAFC),
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 15,
          color: const Color(0xFFE2E8F0),
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 13,
          color: const Color(0xFF94A3B8),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1120),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
