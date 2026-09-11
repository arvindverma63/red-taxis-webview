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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Color(0xFFCD1A21)),
                SizedBox(width: 8),
                Text('Confirm Fleet Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text(
              'Switching to fleet "$tenantId" will save the new fleet credentials and sign you out.\n\nDo you want to proceed?',
              style: const TextStyle(fontSize: 13, height: 1.4),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultFirstTaxis();
    final name = authState.email ?? 'Driver';
    final userId = authState.userId?.toString() ?? 'No ID';

    final themeMode = ref.watch(themeModeProvider);
    final isThemeDark = themeMode == ThemeMode.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: branding.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            MainShell.scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          // 1. Compact Driver Profile Banner
          _buildCompactProfileBanner(branding, name, userId),

          const SizedBox(height: 14),

          // 2. Compact Fleet & Organization Card
          _buildSectionHeader('FLEET & ORGANIZATION', isDark),
          _buildCompactFleetCard(authState, branding, isDark),

          const SizedBox(height: 14),

          // 3. Compact Preferences Group
          _buildSectionHeader('PREFERENCES', isDark),
          _buildGroupCard(
            isDark: isDark,
            children: [
              _buildCompactRow(
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF818CF8),
                title: 'Dark Theme',
                subtitle: 'Toggle dark mode appearance',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: isThemeDark,
                  activeTrackColor: branding.primaryColor,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).toggleTheme(val);
                  },
                ),
              ),
              _buildDivider(isDark),
              _buildCompactRow(
                icon: Icons.notifications_none_outlined,
                iconColor: const Color(0xFF38BDF8),
                title: 'Push Notifications',
                subtitle: 'Job offers & booking status alerts',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: _pushNotifications,
                  activeTrackColor: branding.primaryColor,
                  onChanged: (val) {
                    setState(() => _pushNotifications = val);
                    _saveSetting('settings_push', val);
                  },
                ),
              ),
              _buildDivider(isDark),
              _buildCompactRow(
                icon: Icons.sms_outlined,
                iconColor: const Color(0xFF34D399),
                title: 'SMS Dispatch Alerts',
                subtitle: 'Direct SMS job dispatch notifications',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: _smsAlerts,
                  activeTrackColor: branding.primaryColor,
                  onChanged: (val) {
                    setState(() => _smsAlerts = val);
                    _saveSetting('settings_sms', val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Compact Device & Tracking Group
          _buildSectionHeader('DEVICE & TRACKING', isDark),
          _buildGroupCard(
            isDark: isDark,
            children: [
              _buildCompactRow(
                icon: Icons.gps_fixed_outlined,
                iconColor: const Color(0xFFFB923C),
                title: 'Background GPS',
                subtitle: 'Continuous location streaming on duty',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: _gpsTracking,
                  activeTrackColor: branding.primaryColor,
                  onChanged: (val) {
                    setState(() => _gpsTracking = val);
                    _saveSetting('settings_gps', val);
                  },
                ),
              ),
              _buildDivider(isDark),
              _buildCompactRow(
                icon: Icons.screen_lock_rotation_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: 'Keep Screen Awake',
                subtitle: 'Prevent screen timeout during active shifts',
                isDark: isDark,
                trailing: Switch.adaptive(
                  value: _screenAlwaysOn,
                  activeTrackColor: branding.primaryColor,
                  onChanged: (val) {
                    setState(() => _screenAlwaysOn = val);
                    _saveSetting('settings_screen', val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 5. App Version Footer
          Center(
            child: Text(
              '${branding.name.toUpperCase()} DRIVER • v1.0.0 (Build 42)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCompactProfileBanner(TenantBranding branding, String name, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [branding.gradientStart, branding.gradientMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: branding.primaryColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              (name.trim().isNotEmpty ? name.trim()[0] : 'D').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Driver ID: $userId',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  branding.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFleetCard(AuthState authState, TenantBranding branding, bool isDark) {
    final tenantId = authState.tenantId ?? branding.tenantId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: branding.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(6),
            child: BrandedLogo(
              branding: branding,
              size: 24,
              fallbackIcon: Icons.domain_rounded,
              fallbackIconColor: branding.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      branding.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: $tenantId',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _handleChangeFleet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: branding.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: branding.primaryColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 14, color: branding.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'Switch',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: branding.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildCompactRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? AppTheme.textDarkPrimary : AppTheme.textLightPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: trailing,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      endIndent: 12,
      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.08),
    );
  }
}
