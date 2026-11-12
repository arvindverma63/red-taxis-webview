import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import 'fleet_qr_parser.dart';
import 'qr_image_decoder.dart';

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
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  late AnimationController _laserAnimController;
  bool _torchEnabled = false;
  String? _parseError;
  bool _isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    try {
      if (Platform.isAndroid) {
        _controller?.pauseCamera();
      }
      _controller?.resumeCamera();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _laserAnimController.dispose();
    super.dispose();
  }

  Timer? _errorTimer;
  String? _lastRejectedCode;
  bool _importing = false;

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _errorTimer?.cancel();
    setState(() => _parseError = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _parseError = null);
    });
  }

  /// Accepts a parse result: closes with the fleet details, or explains why the
  /// code was rejected. Returns true when accepted.
  bool _handleResult(FleetQrResult result) {
    if (result.isOk) {
      _isProcessing = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(result.payload);
      return true;
    }
    _showError(result.message);
    return false;
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      final code = scanData.code;
      if (code == null || code.isEmpty || _isProcessing || !mounted) return;
      // The camera re-reports the same code every frame; only react once per
      // distinct rejected code so the message doesn't flicker or spam.
      if (code == _lastRejectedCode) return;
      if (!_handleResult(parseFleetQr(code))) {
        _lastRejectedCode = code;
        Future<void>.delayed(const Duration(seconds: 4), () {
          if (_lastRejectedCode == code) _lastRejectedCode = null;
        });
      }
    }, onError: (err) {
      debugPrint('QR Scanner camera notice: $err');
    });
  }

  /// Import a QR code from an image in the gallery / files.
  Future<void> _importFromImage() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return; // cancelled
      final text = await decodeQrFromImageFile(path);
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        _showError(const FleetQrResult.fail(FleetQrFailure.noCodeFound).message);
        return;
      }
      _handleResult(parseFleetQr(text));
    } catch (_) {
      _showError('Could not read that image. Please try a different one.');
    } finally {
      if (mounted) setState(() => _importing = false);
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
    if (text == null || text.trim().isEmpty) {
      _showError('Clipboard is empty. Copy your fleet activation code or link first.');
      return;
    }
    _handleResult(parseFleetQr(text));
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
                      'Point camera at your fleet activation QR code',
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
                      onPressed: () async {
                        try {
                          await _controller?.toggleFlash();
                          setState(() {
                            _torchEnabled = !_torchEnabled;
                          });
                        } catch (_) {}
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
                    child: QRView(
                      key: qrKey,
                      onQRViewCreated: _onQRViewCreated,
                      overlay: QrScannerOverlayShape(
                        borderColor: primaryColor,
                        borderRadius: 16,
                        borderLength: 30,
                        borderWidth: 4,
                        cutOutSize: 240,
                      ),
                      onPermissionSet: (ctrl, p) {
                        if (!p && mounted) {
                          setState(() {
                            _parseError = 'Camera permission required to scan QR code.';
                          });
                        }
                      },
                    ),
                  ),
                ),

                // Animated scanning laser line
                Positioned(
                  child: SizedBox(
                    width: 230,
                    height: 230,
                    child: AnimatedBuilder(
                      animation: _laserAnimController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            Positioned(
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
                            ),
                          ],
                        );
                      },
                    ),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importing ? null : _importFromImage,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_importing ? 'Reading image...' : 'Upload QR code image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
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
                        tenantId: 'org_ace_taxis',
                        tenantKey: 'tk_live_ace_staging_2026',
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
