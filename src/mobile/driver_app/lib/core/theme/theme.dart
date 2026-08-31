import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppTheme {
  // Brand color palette
  static const Color primaryRed = Color(0xFFE53935);
  static const Color primaryDarkRed = Color(0xFFB71C1C);
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1E1E24);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color textDarkPrimary = Color(0xFFECEFF1);
  static const Color textDarkSecondary = Color(0xFF90A4AE);
  static const Color textLightPrimary = Color(0xFF263238);
  static const Color textLightSecondary = Color(0xFF546E7A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: primaryDarkRed,
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
          backgroundColor: primaryRed,
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: primaryDarkRed,
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
          backgroundColor: primaryRed,
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
