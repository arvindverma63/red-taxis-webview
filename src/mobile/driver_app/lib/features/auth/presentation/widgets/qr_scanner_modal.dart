import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerModal extends StatefulWidget {
  const QrScannerModal({super.key});

  static Future<Map<String, String>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QrScannerModal(),
    );
  }

  @override
  State<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends State<QrScannerModal>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimController;
  bool _torchEnabled = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Map<String, String>? _parseQrPayload(String raw) {
    final clean = raw.trim();

    // 1. Check if JSON payload: {"tenantId": "...", "tenantKey": "..."}
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final data = jsonDecode(clean);
        if (data is Map<String, dynamic>) {
          final tenantId = data['tenantId']?.toString() ?? data['id']?.toString() ?? data['fleetId']?.toString();
          final tenantKey = data['tenantKey']?.toString() ?? data['key']?.toString() ?? data['apiKey']?.toString();
          final companyName = data['companyName']?.toString() ?? data['name']?.toString() ?? data['brand']?.toString();
          final primaryColour = data['primaryColour']?.toString() ?? data['primaryColor']?.toString() ?? data['color']?.toString();

          if (tenantId != null && tenantId.isNotEmpty) {
            return {
              'tenantId': tenantId,
              'tenantKey': tenantKey ?? '',
              if (companyName != null) 'companyName': companyName,
              if (primaryColour != null) 'primaryColour': primaryColour,
            };
          }
        }
      } catch (_) {}
    }

    // 2. Check if deep link URL: redtaxis://fleet?tenantId=org_...&tenantKey=rtk_...
    // or https://staging.redtaxi.co.uk/driver?tenantId=org_...
    if (clean.contains('://') || clean.contains('tenantId=')) {
      try {
        final uri = Uri.parse(clean);
        final tenantId = uri.queryParameters['tenantId'] ?? uri.queryParameters['id'] ?? uri.queryParameters['tenant'];
        final tenantKey = uri.queryParameters['tenantKey'] ?? uri.queryParameters['key'] ?? uri.queryParameters['token'];
        final companyName = uri.queryParameters['companyName'] ?? uri.queryParameters['name'] ?? uri.queryParameters['fleet'];
        final primaryColour = uri.queryParameters['primaryColour'] ?? uri.queryParameters['primaryColor'] ?? uri.queryParameters['color'];

        if (tenantId != null && tenantId.isNotEmpty) {
          return {
            'tenantId': tenantId,
            'tenantKey': tenantKey ?? '',
            if (companyName != null) 'companyName': companyName,
            if (primaryColour != null) 'primaryColour': primaryColour,
          };
        }
      } catch (_) {}
    }

    // 3. Check if colon / pipe separated format: "org_...:rtk_pub_..." or "org_...|rtk_pub_...|companyName"
    if (clean.contains(':') || clean.contains('|')) {
      final delimiter = clean.contains(':') ? ':' : '|';
      final parts = clean.split(delimiter);
      if (parts.length >= 2) {
        final map = {
          'tenantId': parts[0].trim(),
          'tenantKey': parts[1].trim(),
        };
        if (parts.length >= 3 && parts[2].trim().isNotEmpty) {
          map['companyName'] = parts[2].trim();
        }
        return map;
      }
    }

    // 4. Fallback if single identifier is supplied
    if (clean.startsWith('org_') || clean.startsWith('fleet_')) {
      return {
        'tenantId': clean,
        'tenantKey': '',
      };
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final parsed = _parseQrPayload(rawValue);
        if (parsed != null) {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(parsed);
          return;
        } else {
          setState(() {
            _parseError = 'Invalid QR code. Please scan a valid fleet setup code.';
          });
        }
      }
    }
  }

  void _selectPreset(String tenantId, String tenantKey) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop({
      'tenantId': tenantId,
      'tenantKey': tenantKey,
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      final parsed = _parseQrPayload(text);
      if (parsed != null && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(parsed);
      } else {
        setState(() {
          _parseError = 'Clipboard does not contain a valid fleet code or URL.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Fleet QR Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Point camera at your fleet setup QR code',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _torchEnabled ? Colors.amber : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                      onPressed: () {
                        _scannerController.toggleTorch();
                        setState(() {
                          _torchEnabled = !_torchEnabled;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Camera Viewfinder Box
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                  ),
                ),

                // Viewfinder Target Frame
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor,
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Animated scanning laser line
                      AnimatedBuilder(
                        animation: _laserAnimController,
                        builder: (context, child) {
                          return Positioned(
                            top: _laserAnimController.value * 210,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withValues(alpha: 0.1),
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Parse error notice
                if (_parseError != null)
                  Positioned(
                    bottom: 24,
                    left: 32,
                    right: 32,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _parseError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Quick Preset Test & Clipboard Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DEMO FLEET PRESETS / TEST SHORTCUTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                    InkWell(
                      onTap: _pasteFromClipboard,
                      child: Row(
                        children: [
                          Icon(Icons.content_paste_rounded, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Paste Code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPresetChip(
                        label: 'Instacreator (Live API)',
                        tenantId: 'org_08f19f20899e43308c1c1db3',
                        tenantKey: 'rtk_pub_a7b32fd9677198faa9d8d2f932e62b433322e97991ffa144ee8d66b22416a0db',
                        icon: Icons.business_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Red Taxis (Live)',
                        tenantId: 'org_red_taxis',
                        tenantKey: 'tk_live_red_taxis_dev',
                        icon: Icons.directions_car_rounded,
                        color: const Color(0xFFD32F2F),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Ace Taxis (Staging)',
                        tenantId: 'org_ace_taxis',
                        tenantKey: 'tk_live_ace_staging_2026',
                        icon: Icons.speed_rounded,
                        color: const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'First Taxis',
                        tenantId: 'org_first_taxis',
                        tenantKey: 'tk_live_8f93c72b10a94e82b7',
                        icon: Icons.local_taxi_rounded,
                        color: const Color(0xFFCD1A21),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String tenantId,
    required String tenantKey,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _selectPreset(tenantId, tenantKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
