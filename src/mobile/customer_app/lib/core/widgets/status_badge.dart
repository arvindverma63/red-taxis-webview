import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Color? customColor;

  const StatusBadge({
    super.key,
    required this.status,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    final lower = status.toLowerCase();
    if (customColor != null) {
      bg = customColor!.withOpacity(0.12);
      fg = customColor!;
    } else if (lower.contains('accept') || lower.contains('complete') || lower.contains('arrived')) {
      bg = const Color(0xFF10B981).withOpacity(0.12);
      fg = const Color(0xFF10B981);
    } else if (lower.contains('progress') || lower.contains('route') || lower.contains('active') || lower.contains('trip')) {
      bg = const Color(0xFF3B82F6).withOpacity(0.12);
      fg = const Color(0xFF3B82F6);
    } else if (lower.contains('pending') || lower.contains('sent') || lower.contains('allocat')) {
      bg = const Color(0xFFF59E0B).withOpacity(0.12);
      fg = const Color(0xFFD97706);
    } else if (lower.contains('cancel') || lower.contains('reject')) {
      bg = const Color(0xFFEF4444).withOpacity(0.12);
      fg = const Color(0xFFEF4444);
    } else {
      bg = const Color(0xFF64748B).withOpacity(0.12);
      fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
