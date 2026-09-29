import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:driver_app/core/theme/theme.dart';

class LocationDisclosureDialog extends StatelessWidget {
  final String fleetName;
  final bool isReadOnly;

  static const String storageKey = 'has_accepted_location_disclosure';
  static bool? _inMemoryAccepted;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  const LocationDisclosureDialog({
    super.key,
    this.fleetName = 'Red Taxis',
    this.isReadOnly = false,
  });

  /// Check whether the user has previously acknowledged and accepted the prominent disclosure
  static Future<bool> hasAccepted() async {
    if (_inMemoryAccepted != null) return _inMemoryAccepted!;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return _inMemoryAccepted ?? false;
    }
    try {
      final value = await _storage.read(key: storageKey);
      final accepted = value == 'true';
      _inMemoryAccepted = accepted;
      return accepted;
    } catch (_) {
      return false;
    }
  }

  /// Save disclosure acceptance state
  static Future<void> setAccepted(bool accepted) async {
    _inMemoryAccepted = accepted;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _storage.write(key: storageKey, value: accepted ? 'true' : 'false');
    } catch (_) {}
  }

  /// Show the Google Play policy compliant prominent disclosure dialog
  static Future<bool> show(
    BuildContext context, {
    String fleetName = 'Red Taxis',
    bool isReadOnly = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: isReadOnly,
      builder: (ctx) => LocationDisclosureDialog(
        fleetName: fleetName,
        isReadOnly: isReadOnly,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Icon Badge
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryRed.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primaryRed,
                      size: 34,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Title
              Text(
                'Background Location Access',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Prominent Disclosure & Consent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryRed,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Highlighted Mandatory Prominent Disclosure Callout Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFFECDD3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.primaryRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF881337),
                          ),
                          children: [
                            TextSpan(
                              text: '$fleetName collects location data ',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const TextSpan(
                              text: 'to enable real-time ride dispatching, route navigation, nearby passenger pickup matching, and accurate arrival ETAs ',
                            ),
                            const TextSpan(
                              text: 'even when the app is closed or not in use.',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Feature Breakdown List
              _buildFeatureItem(
                context,
                icon: Icons.local_taxi_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Trip Dispatch & Allocation',
                description:
                    'Allows the dispatch system and nearby passengers to assign booking requests to your vehicle based on real-time proximity.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureItem(
                context,
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Route Navigation & Fare Calculation',
                description:
                    'Accurately calculates mileage, travel duration, and route progress to ensure accurate driver earnings and fare settlements.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureItem(
                context,
                icon: Icons.phonelink_lock_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Continuous Background Tracking',
                description:
                    'Streams your location while you are On Duty (Online), allowing you to use external navigation apps (e.g. Google Maps) or lock your phone screen.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureItem(
                context,
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Privacy & Driver Control',
                description:
                    'Tracking stops immediately when you go Off Duty (Offline) or log out. Your location data is encrypted and is never sold or used for advertising.',
                isDark: isDark,
              ),
              const SizedBox(height: 22),

              // 5. Action Buttons
              if (isReadOnly)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await setAccepted(true);
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Agree & Enable Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await setAccepted(false);
                        if (context.mounted) {
                          Navigator.of(context).pop(false);
                        }
                      },
                      child: const Text(
                        'Deny & Stay Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
