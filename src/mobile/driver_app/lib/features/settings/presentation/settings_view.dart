import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/auth/auth.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _pushNotifications = true;
  bool _gpsTracking = true;
  bool _smsAlerts = false;
  bool _screenAlwaysOn = true;
  bool _isLoading = true;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final push = await _storage.read(key: 'settings_push') ?? 'true';
      final gps = await _storage.read(key: 'settings_gps') ?? 'true';
      final sms = await _storage.read(key: 'settings_sms') ?? 'false';
      final screen = await _storage.read(key: 'settings_screen') ?? 'true';

      if (mounted) {
        setState(() {
          _pushNotifications = push == 'true';
          _gpsTracking = gps == 'true';
          _smsAlerts = sms == 'true';
          _screenAlwaysOn = screen == 'true';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (_) {}
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppTheme.primaryRed,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withOpacity(0.5) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final name = authState.email ?? 'Driver';
    final userId = authState.userId?.toString() ?? 'No ID';
    
    // Watch ThemeMode to update switch
    final themeMode = ref.watch(themeModeProvider);
    final isThemeDark = themeMode == ThemeMode.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRed)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Driver Profile Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryRed, AppTheme.primaryDarkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (name.trim().isNotEmpty ? name.trim()[0] : 'D').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Driver ID: $userId',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Appearance Section
          _buildSectionCard(
            'APPEARANCE',
            [
              _buildToggle(
                label: 'Dark Theme',
                value: isThemeDark,
                icon: Icons.dark_mode_outlined,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).toggleTheme(val);
                },
              ),
            ],
          ),

          // 3. Notifications Section
          _buildSectionCard(
            'NOTIFICATIONS',
            [
              _buildToggle(
                label: 'Push Notifications',
                value: _pushNotifications,
                icon: Icons.notifications_none_outlined,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  _saveSetting('settings_push', val);
                },
              ),
              _buildToggle(
                label: 'SMS Dispatch Alerts',
                value: _smsAlerts,
                icon: Icons.sms_outlined,
                onChanged: (val) {
                  setState(() => _smsAlerts = val);
                  _saveSetting('settings_sms', val);
                },
              ),
            ],
          ),

          // 4. Device Section
          _buildSectionCard(
            'DEVICE OPTIONS',
            [
              _buildToggle(
                label: 'Background GPS Tracking',
                value: _gpsTracking,
                icon: Icons.gps_fixed_outlined,
                onChanged: (val) {
                  setState(() => _gpsTracking = val);
                  _saveSetting('settings_gps', val);
                },
              ),
              _buildToggle(
                label: 'Keep Screen Awake',
                value: _screenAlwaysOn,
                icon: Icons.screen_lock_rotation_outlined,
                onChanged: (val) {
                  setState(() => _screenAlwaysOn = val);
                  _saveSetting('settings_screen', val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
