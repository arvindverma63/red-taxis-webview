import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:driver_app/core/theme/theme.dart';

class PrivacyPolicyDialog extends StatefulWidget {
  final String fleetName;
  final int initialTabIndex;
  final String? privacyPolicyUrl;
  final String? termsUrl;

  static const String defaultPrivacyUrl = 'https://staging-saas.redtaxi.co.uk/privacy-policy';
  static const String defaultTermsUrl = 'https://staging-saas.redtaxi.co.uk/terms-and-conditions';

  const PrivacyPolicyDialog({
    super.key,
    this.fleetName = 'Red Taxis',
    this.initialTabIndex = 0,
    this.privacyPolicyUrl,
    this.termsUrl,
  });

  /// Show the Google Play / GDPR compliant Privacy Policy and Terms of Service dialog
  static Future<bool> show(
    BuildContext context, {
    String fleetName = 'Red Taxis',
    int initialTab = 0,
    String? privacyPolicyUrl,
    String? termsUrl,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PrivacyPolicyDialog(
        fleetName: fleetName,
        initialTabIndex: initialTab,
        privacyPolicyUrl: privacyPolicyUrl,
        termsUrl: termsUrl,
      ),
    );
    return result ?? false;
  }

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openExternalPolicy() async {
    final isPrivacyTab = _tabController.index == 0;
    final targetUrl = isPrivacyTab
        ? (widget.privacyPolicyUrl ?? PrivacyPolicyDialog.defaultPrivacyUrl)
        : (widget.termsUrl ?? PrivacyPolicyDialog.defaultTermsUrl);
    final uri = Uri.tryParse(targetUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryColor = AppTheme.primaryRed;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 640,
        ),
        child: Column(
          children: [
            // 1. Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.fleetName} Legal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Privacy Policy & Terms of Service',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // 2. Tab Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Privacy Policy'),
                    Tab(text: 'Terms of Service'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Tab Content (Scrollable)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrivacyTab(isDark),
                  _buildTermsTab(isDark),
                ],
              ),
            ),

            // 4. Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _openExternalPolicy,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'Web Version',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'I Understand',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCallout(
            isDark: isDark,
            icon: Icons.verified_user_rounded,
            title: 'Your Privacy Is Protected',
            description:
                '${widget.fleetName} complies with Google Play User Data policies, UK GDPR, and data protection regulations to safeguard your identity and telemetry.',
          ),
          const SizedBox(height: 14),
          _buildClause(
            isDark: isDark,
            number: '1',
            title: 'Information We Collect',
            points: [
              'Driver Credentials: Account username, driver ID, telephone number, and session security tokens.',
              'Compliance Records: Vehicle registration, insurance certificate dates, licence badges, and MOT status.',
              'Real-Time Location & Telemetry: High-accuracy GPS coordinates collected while On Duty (even when the app is backgrounded or screen locked) to enable ride dispatching, route navigation, and arrival ETAs.',
              'Shift & Financial Data: Completed ride fares, travel mileage, waiting times, and driver settlement earnings.',
            ],
          ),
          const SizedBox(height: 12),
          _buildClause(
            isDark: isDark,
            number: '2',
            title: 'How We Use Your Data',
            points: [
              'Automated ride dispatching: Matching nearby passengers to your vehicle based on real-time proximity.',
              'Fare settlement and earnings calculation: Accurately auditing trip distances and journey durations.',
              'Driver & Passenger safety: Sharing vehicle approach status with booked passengers and dispatch controllers.',
              'Regulatory audit compliance with local licensing authorities and transport councils.',
            ],
          ),
          const SizedBox(height: 12),
          _buildClause(
            isDark: isDark,
            number: '3',
            title: 'Background Location Transparency',
            points: [
              'Location tracking is ONLY active while you are signed into an active shift (On Duty).',
              'Tracking terminates immediately when you toggle to "Go Offline" (Off Duty) or sign out.',
              'Your location is never sold, licensed, or shared with third-party advertisers or data brokers.',
            ],
          ),
          const SizedBox(height: 12),
          _buildClause(
            isDark: isDark,
            number: '4',
            title: 'Data Security & Driver Rights',
            points: [
              'All telemetry is encrypted in transit using industry-standard TLS 1.3 encryption.',
              'Authentication tokens are securely stored on-device using hardware-backed EncryptedSharedPreferences / Keychain.',
              'You may request access to, correction of, or permanent deletion of your driver profile by contacting your fleet administrator.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCallout(
            isDark: isDark,
            icon: Icons.gavel_rounded,
            title: 'Driver Terms of Service',
            description:
                'By accessing the ${widget.fleetName} driver platform, you agree to adhere to all transport authority standards and fleet operational guidelines.',
          ),
          const SizedBox(height: 14),
          _buildClause(
            isDark: isDark,
            number: '1',
            title: 'Driver Eligibility & Compliance',
            points: [
              'You must maintain an active, valid private hire or taxi driving licence issued by the relevant licensing authority.',
              'Your vehicle must hold valid commercial insurance, road tax, and a current MOT inspection certificate at all times.',
              'Expired compliance documents must be updated promptly via the Document Upload portal.',
            ],
          ),
          const SizedBox(height: 12),
          _buildClause(
            isDark: isDark,
            number: '2',
            title: 'Platform Use & Account Security',
            points: [
              'Driver credentials and tenant activation keys are strictly non-transferable.',
              'You must not permit any unauthorized person to operate your vehicle under your driver profile.',
              'You agree to use hands-free device mounts and comply with all mobile phone driving laws.',
            ],
          ),
          const SizedBox(height: 12),
          _buildClause(
            isDark: isDark,
            number: '3',
            title: 'Dispatches, Fares & Cancellations',
            points: [
              'Job offers accepted through the dispatch system must be fulfilled professionally in accordance with fleet standards.',
              'Fares, waiting times, and tolls must be calculated according to official fleet tariff structures.',
              'Cash bookings must be collected accurately and recorded directly in the driver app.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallout({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFFECDD3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 20),
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
                    color: isDark ? Colors.white : const Color(0xFF881337),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF9F1239),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClause({
    required bool isDark,
    required String number,
    required String title,
    required List<String> points,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...points.map((pt) => Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pt,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
