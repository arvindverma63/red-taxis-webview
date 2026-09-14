import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A circular avatar showing a network image when available, otherwise the
/// initials derived from [name] on a brand-tinted background.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
  });

  /// Display name used to derive initials and the fallback tint.
  final String name;

  /// Optional avatar image URL. Falls back to initials on error/absence.
  final String? imageUrl;

  /// Diameter of the avatar in logical pixels.
  final double size;

  /// Up to two uppercase initials from the name.
  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }

  /// A stable tint derived from the name so each person reads consistently.
  Color _backgroundColor() {
    final hash = name.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final alpha = 0.18 + (hash % 5) * 0.04; // 0.18–0.34 spread
    return AppColors.brand.withValues(alpha: alpha);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _backgroundColor(),
        shape: BoxShape.circle,
      ),
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) => _initialsLabel(context),
            )
          : _initialsLabel(context),
    );
  }

  Widget _initialsLabel(BuildContext context) {
    return Center(
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.brand,
              fontSize: size * 0.36,
            ),
      ),
    );
  }
}
