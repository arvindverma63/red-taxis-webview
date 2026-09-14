import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/token_storage.dart' show secureStorageProvider;

/// Persistence key for the user's theme preference.
const _themeModeKey = 'theme_mode';

/// First-run default. Dark matches the GoRide kit's premium look; the user can
/// switch to Light or System from Settings → Appearance and the choice persists.
const ThemeMode kDefaultThemeMode = ThemeMode.dark;

ThemeMode _parseThemeMode(String? raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'system':
      return ThemeMode.system;
    case 'dark':
      return ThemeMode.dark;
    default:
      return kDefaultThemeMode;
  }
}

/// Reads the persisted theme preference at boot. Call from `main()` before
/// `runApp` and feed the result into [initialThemeModeProvider] via a
/// ProviderScope override so the very first frame already paints in the chosen
/// mode (no light/dark flash on cold start).
Future<ThemeMode> loadInitialThemeMode(FlutterSecureStorage storage) async {
  try {
    return _parseThemeMode(await storage.read(key: _themeModeKey));
  } catch (_) {
    // Secure storage can throw on a fresh / locked keystore — fall back.
    return kDefaultThemeMode;
  }
}

/// Seeded in `main()` with the boot-loaded value. Defaults to
/// [kDefaultThemeMode] when no override is supplied (e.g. widget tests).
final initialThemeModeProvider = Provider<ThemeMode>((ref) => kDefaultThemeMode);

/// Holds the active [ThemeMode] and persists changes. Watched by the root
/// [MaterialApp] and driven by the Settings → Appearance selector.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  /// Switches the app theme and persists the choice. In-memory change applies
  /// immediately; writing to secure storage is best-effort.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: _themeModeKey, value: mode.name);
    } catch (_) {
      // Persisting failed (locked keystore etc.) — the live theme still changed.
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
