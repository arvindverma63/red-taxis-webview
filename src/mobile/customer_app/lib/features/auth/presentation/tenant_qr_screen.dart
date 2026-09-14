import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_notifier.dart';

class TenantQrScreen extends ConsumerStatefulWidget {
  const TenantQrScreen({super.key});

  @override
  ConsumerState<TenantQrScreen> createState() => _TenantQrScreenState();
}

class _TenantQrScreenState extends ConsumerState<TenantQrScreen> {
  final _tenantIdController = TextEditingController();
  final _tenantKeyController = TextEditingController();
  bool _showScanner = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _tenantIdController.dispose();
    _tenantKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect(String tenantId, {String? key}) async {
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).resolveTenant(tenantId, tenantKey: key);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to fleet: $tenantId')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(tenantBrandingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet & Company Setup'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect to Your Local Fleet',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Scan a fleet QR code or enter your taxi company ID to load their custom booking rates and branding.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              if (_showScanner) ...[
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: branding.primaryColor, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final rawValue = barcode.rawValue;
                        if (rawValue != null && rawValue.isNotEmpty) {
                          setState(() => _showScanner = false);
                          _handleConnect(rawValue);
                          break;
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showScanner = false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Close Camera'),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                AppButton(
                  text: 'Scan Fleet QR Code',
                  icon: Icons.qr_code_scanner_rounded,
                  variant: ButtonVariant.secondary,
                  onPressed: () => setState(() => _showScanner = true),
                ),
                const SizedBox(height: 24),
              ],

              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Manual Entry',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _tenantIdController,
                label: 'Tenant ID',
                hintText: 'e.g. org_ace_taxis',
                prefixIcon: Icons.domain_rounded,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _tenantKeyController,
                label: 'Tenant Key (Optional)',
                hintText: 'e.g. demo_key',
                prefixIcon: Icons.key_rounded,
              ),
              const SizedBox(height: 20),
              AppButton(
                text: 'Apply Fleet Settings',
                isLoading: _isLoading,
                onPressed: () {
                  if (_tenantIdController.text.trim().isNotEmpty) {
                    _handleConnect(
                      _tenantIdController.text.trim(),
                      key: _tenantKeyController.text.trim().isNotEmpty
                          ? _tenantKeyController.text.trim()
                          : null,
                    );
                  }
                },
                branding: branding,
              ),
              const SizedBox(height: 24),

              // Demo fleet presets
              Text(
                'Test Presets',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Ace Taxis'),
                    onPressed: () => _handleConnect('org_ace_taxis'),
                  ),
                  ActionChip(
                    label: const Text('Instacreator'),
                    onPressed: () => _handleConnect('org_08f19f20899e43308c1c1db3'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
