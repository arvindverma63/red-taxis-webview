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
      builder: (ctx) => const QrScannerModal(),
    );
  }

  @override
  State<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends State<QrScannerModal> with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimController;
  bool _torchEnabled = false;
  bool _hasDetected = false;
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
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Map<String, String>? _parseBarcodeData(String raw) {
    final clean = raw.trim();

    // 1. Check if JSON format: {"tenantId": "...", "tenantKey": "..."}
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is Map<String, dynamic>) {
          final tenantId = decoded['tenantId']?.toString() ?? decoded['id']?.toString() ?? decoded['orgId']?.toString();
          final tenantKey = decoded['tenantKey']?.toString() ?? decoded['key']?.toString() ?? decoded['accessKey']?.toString();
          if (tenantId != null && tenantId.isNotEmpty) {
            return {
              'tenantId': tenantId,
              'tenantKey': tenantKey ?? '',
            };
          }
        }
      } catch (_) {}
    }

    // 2. Check if URI / URL format (e.g. firsttaxis://setup?tenantId=...&tenantKey=... or tenant:org_first_taxis?key=...)
    try {
      final uri = Uri.parse(clean);
      if (uri.queryParameters.containsKey('tenantId') || uri.queryParameters.containsKey('tenant_id') || uri.queryParameters.containsKey('key')) {
        final tenantId = uri.queryParameters['tenantId'] ?? uri.queryParameters['tenant_id'] ?? uri.path.replaceAll('/', '');
        final tenantKey = uri.queryParameters['tenantKey'] ?? uri.queryParameters['tenant_key'] ?? uri.queryParameters['key'] ?? '';
        if (tenantId.isNotEmpty) {
          return {
            'tenantId': tenantId,
            'tenantKey': tenantKey,
          };
        }
      }
    } catch (_) {}

    // 3. Check if colon / pipe separated format: "org_first_taxis:tk_live_..."
    if (clean.contains(':') || clean.contains('|')) {
      final delimiter = clean.contains(':') ? ':' : '|';
      final parts = clean.split(delimiter);
      if (parts.length >= 2) {
        return {
          'tenantId': parts[0].trim(),
          'tenantKey': parts[1].trim(),
        };
      }
    }

    // 4. Fallback if single identifier is supplied
    if (clean.startsWith('org_')) {
      return {
        'tenantId': clean,
        'tenantKey': '',
      };
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final result = _parseBarcodeData(rawValue);
        if (result != null) {
          _hasDetected = true;
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(result);
          return;
        } else {
          setState(() {
            _parseError = 'Unrecognized QR code format. Please use a fleet QR.';
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
      final result = _parseBarcodeData(text);
      if (result != null) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(result);
        }
      } else {
        setState(() {
          _parseError = 'Pasted text does not contain valid fleet credentials.';
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
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Modal Top App Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Fleet QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Point camera at your fleet activation QR',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Torch Toggle
                IconButton(
                  icon: Icon(
                    _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchEnabled ? Colors.amber : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                    setState(() => _torchEnabled = !_torchEnabled);
                  },
                ),
                // Camera Flip
                IconButton(
                  icon: Icon(
                    Icons.flip_camera_ios_rounded,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  onPressed: () => _scannerController.switchCamera(),
                ),
                // Close Button
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Camera Viewport & Overlay
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Live Camera Scanner
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
                        label: 'First Taxis (Live)',
                        tenantId: 'org_first_taxis',
                        tenantKey: 'tk_live_8f93c72b10a94e82b7',
                        icon: Icons.local_taxi_rounded,
                        color: const Color(0xFFCD1A21),
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
                        label: 'Red Taxis (Dev)',
                        tenantId: 'org_red_taxis',
                        tenantKey: 'tk_live_red_taxis_dev',
                        icon: Icons.directions_car_rounded,
                        color: const Color(0xFFD32F2F),
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
