import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/branded_logo.dart';

class CustomerSettingsScreen extends ConsumerStatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  ConsumerState<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends ConsumerState<CustomerSettingsScreen> {
  bool _pushNotifications = true;
  bool _smsUpdates = true;

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(tenantBrandingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fleet & Organization Management
              Text('FLEET & COMPANY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Row(
                  children: [
                    BrandedLogo(branding: branding, size: 36, isDark: isDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(branding.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('ID: ${branding.tenantId}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/auth/qr-scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: branding.primaryColor.withOpacity(0.12),
                        foregroundColor: branding.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Switch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Appearance
              Text('APPEARANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Reduce glare and battery consumption', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      value: themeMode == ThemeMode.dark,
                      activeColor: branding.primaryColor,
                      onChanged: (val) {
                        themeModeNotifier.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notifications
              Text('NOTIFICATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Driver arrival and booking updates', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      value: _pushNotifications,
                      activeColor: branding.primaryColor,
                      onChanged: (val) => setState(() => _pushNotifications = val),
                    ),
                    const Divider(height: 1, indent: 16),
                    SwitchListTile(
                      title: const Text('SMS Text Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Text notifications when vehicle arrives', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      value: _smsUpdates,
                      activeColor: branding.primaryColor,
                      onChanged: (val) => setState(() => _smsUpdates = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About
              Center(
                child: Column(
                  children: [
                    Text('Customer App v1.0.0', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Text('Powered by Red Taxis Platform', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
