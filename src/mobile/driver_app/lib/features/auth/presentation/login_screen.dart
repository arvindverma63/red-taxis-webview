import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/auth/presentation/widgets/qr_scanner_modal.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _tenantFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _tenantIdController = TextEditingController();
  final _tenantKeyController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureTenantKey = true;
  bool _rememberMe = true;
  bool _isResolvingTenant = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tenantIdController.dispose();
    _tenantKeyController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final result = await QrScannerModal.show(context);
    if (result != null && mounted) {
      final tenantId = result['tenantId'] ?? '';
      final tenantKey = result['tenantKey'] ?? '';

      setState(() {
        _tenantIdController.text = tenantId;
        _tenantKeyController.text = tenantKey;
      });

      // Automatically connect fleet upon successful scan
      if (tenantId.isNotEmpty) {
        _submitTenantConfig();
      }
    }
  }

  Future<void> _submitTenantConfig() async {
    FocusScope.of(context).unfocus();
    final tenantId = _tenantIdController.text.trim();
    final tenantKey = _tenantKeyController.text.trim();

    if (tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or scan a Tenant ID')),
      );
      return;
    }

    setState(() => _isResolvingTenant = true);

    final success = await ref.read(authProvider.notifier).resolveAndSaveTenant(
          tenantId,
          tenantKey,
        );

    if (mounted) {
      setState(() => _isResolvingTenant = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Connected to ${ref.read(authProvider).tenantBranding?.name ?? tenantId}!'),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  void _submitLogin() {
    FocusScope.of(context).unfocus();
    if (_loginFormKey.currentState!.validate()) {
      ref.read(authProvider.notifier).signIn(
            _usernameController.text.trim(),
            _passwordController.text,
          );
    }
  }

  void _showSwitchFleetDialog() {
    final authState = ref.watch(authProvider);
    final currentFleetName = authState.tenantBranding?.name ?? authState.tenantId ?? 'Current Fleet';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFFCD1A21)),
            SizedBox(width: 8),
            Text('Switch Fleet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'You are currently connected to $currentFleetName.\n\nDo you want to switch to a different fleet organization or scan a new onboarding QR code?',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).switchTenant();
            },
            child: const Text('Switch Fleet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.authenticating || _isResolvingTenant;
    final isConfigured = authState.isTenantConfigured;
    final branding = authState.tenantBranding ?? TenantBranding.defaultFirstTaxis();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Press back again to exit ${branding.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            SystemNavigator.pop();
          }
        },
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Hero Header with Dynamic Branding
                  _buildHeader(branding, isConfigured),

                  // Dynamic Body based on configuration state
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: isConfigured
                        ? _buildLoginForm(authState, branding, isDark)
                        : _buildTenantSetupForm(isDark),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Loading Modal Progress Overlay
            if (isLoading) _buildLoadingOverlay(branding),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TenantBranding branding, bool isConfigured) {
    return ClipPath(
      clipper: HeaderClipper(),
      child: Container(
        height: 270,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              branding.gradientStart,
              branding.gradientMid,
              branding.gradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative background glowing bubbles
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  // Glowing Badge
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: branding.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: isConfigured
                          ? BrandedLogo(
                              branding: branding,
                              size: 54,
                              fit: BoxFit.contain,
                              fallbackIcon: Icons.local_taxi_rounded,
                            )
                          : const Icon(
                              Icons.domain_rounded,
                              color: Color(0xFFCD1A21),
                              size: 42,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isConfigured ? branding.name.toUpperCase() : 'FLEET ONBOARDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isConfigured ? 'Driver Portal' : 'Fleet Activation & QR Setup',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
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

  // ==========================================
  // STATE A: FLEET SETUP & QR ONBOARDING
  // ==========================================
  Widget _buildTenantSetupForm(bool isDark) {
    return Form(
      key: _tenantFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // Primary Scan QR Action Banner Card
          InkWell(
            onTap: _scanQrCode,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFCD1A21), Color(0xFF9E0E14)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCD1A21).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFCD1A21),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Fleet QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1-tap instant fleet activation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Separator "OR ENTER DETAILS MANUALLY"
          Row(
            children: [
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR ENTER MANUALLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[300])),
            ],
          ),

          const SizedBox(height: 16),

          // Tenant ID Input Field
          Text(
            'Tenant ID / Organization Slug',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _tenantIdController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _buildInputDecoration(
              hint: 'e.g. org_red_taxis',
              icon: Icons.domain_rounded,
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 16),

          // Tenant Key Input Field
          Text(
            'Tenant Access Key',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _tenantKeyController,
            obscureText: _obscureTenantKey,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _buildInputDecoration(
              hint: 'e.g. tk_live_...',
              icon: Icons.vpn_key_rounded,
              isDark: isDark,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureTenantKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureTenantKey = !_obscureTenantKey),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Connect Fleet Button
          ElevatedButton(
            onPressed: _isResolvingTenant ? null : _submitTenantConfig,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCD1A21),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isResolvingTenant)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                else ...[
                  const Icon(Icons.link_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Connect Fleet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATE B: EVERYDAY DRIVER LOGIN (2-FIELD)
  // ==========================================
  Widget _buildLoginForm(AuthState authState, TenantBranding branding, bool isDark) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Fleet Badge & Switch Fleet Action Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: branding.primaryColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: branding.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: BrandedLogo(
                    branding: branding,
                    size: 20,
                    fallbackIcon: Icons.domain_rounded,
                    fallbackIconColor: branding.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Fleet',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        branding.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showSwitchFleetDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: branding.primaryColor),
                      const SizedBox(width: 2),
                      Text(
                        'Switch',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: branding.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Error Message Banner if any
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Username Field
          Text(
            'Driver Username / ID',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _buildInputDecoration(
              hint: 'Enter your driver username or ID',
              icon: Icons.person_rounded,
              isDark: isDark,
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your username' : null,
          ),

          const SizedBox(height: 16),

          // Password Field
          Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _buildInputDecoration(
              hint: 'Enter your password',
              icon: Icons.lock_rounded,
              isDark: isDark,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) => val == null || val.isEmpty ? 'Please enter your password' : null,
          ),

          const SizedBox(height: 12),

          // Remember Me Toggle
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: branding.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  onChanged: (val) => setState(() => _rememberMe = val ?? true),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Remember my login on this device',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Sign In Submit Button
          ElevatedButton(
            onPressed: _submitLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: branding.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: branding.primaryColor.withValues(alpha: 0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Sign In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Security SSL Badge
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 14, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  '256-Bit Encrypted Driver Gateway',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCD1A21), width: 1.8),
      ),
    );
  }

  Widget _buildLoadingOverlay(TenantBranding branding) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  color: branding.primaryColor,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Connecting...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authenticating with ${branding.name} secure server',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 15,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
