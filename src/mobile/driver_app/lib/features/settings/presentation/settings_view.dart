import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/navigation/presentation/main_shell.dart';
import 'package:driver_app/features/auth/presentation/widgets/qr_scanner_modal.dart';

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

  Future<void> _handleChangeFleet() async {
    final result = await QrScannerModal.show(context);
    if (result != null && mounted) {
      final tenantId = result['tenantId'] ?? '';
      final tenantKey = result['tenantKey'] ?? '';

      if (tenantId.isNotEmpty) {
        // Confirm switch
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Color(0xFFCD1A21)),
                SizedBox(width: 8),
                Text('Confirm Fleet Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              'Switching to fleet "$tenantId" will save the new fleet credentials and sign you out so you can log in with your credentials for this fleet.\n\nDo you want to proceed?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCD1A21),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(authProvider.notifier).resolveAndSaveTenant(tenantId, tenantKey);
                  await ref.read(authProvider.notifier).signOut();
                },
                child: const Text('Switch Fleet', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
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
            activeTrackColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
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
                  color: primaryColor,
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

  Widget _buildFleetCard(AuthState authState, bool isDark) {
    final branding = authState.tenantBranding ?? TenantBranding.defaultFirstTaxis();
    final tenantId = authState.tenantId ?? branding.tenantId;
    final tenantKey = authState.tenantKey ?? branding.tenantKey;
    final maskedKey = tenantKey.length > 8
        ? '${tenantKey.substring(0, 6)}••••••••${tenantKey.substring(tenantKey.length - 4)}'
        : '••••••••••••';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: branding.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: branding.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(8),
                child: BrandedLogo(
                  branding: branding,
                  size: 28,
                  fallbackIcon: Icons.domain_rounded,
                  fallbackIconColor: branding.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branding.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $tenantId',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tenant Key:',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              Text(
                maskedKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _handleChangeFleet,
            style: OutlinedButton.styleFrom(
              foregroundColor: branding.primaryColor,
              side: BorderSide(color: branding.primaryColor, width: 1.5),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Change Fleet / Scan QR Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultFirstTaxis();
    final name = authState.email ?? 'Driver';
    final userId = authState.userId?.toString() ?? 'No ID';
    
    // Watch ThemeMode to update switch
    final themeMode = ref.watch(themeModeProvider);
    final isThemeDark = themeMode == ThemeMode.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: branding.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            MainShell.scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text('Settings'),
        centerTitle: false,
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
              gradient: LinearGradient(
                colors: [branding.gradientStart, branding.gradientMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: branding.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                          color: Colors.white.withValues(alpha: 0.85),
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

          // 2. Fleet & Organization Section
          _buildSectionCard(
            'FLEET & ORGANIZATION',
            [
              _buildFleetCard(authState, isDark),
            ],
          ),

          // 3. Appearance Section
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

          // 4. Notifications Section
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

          // 5. Device Section
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
