import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// The GoRide two-segment toggle (Recent / Suggested). The active segment is a
/// filled brand pill; the inactive segments sit on a soft surface track.
///
/// Generic over any number of segments though GoRide uses two. Theme-only.
/// Feature-local — flag for promotion if reused outside booking search.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// Ordered segment labels.
  final List<String> segments;

  /// Currently active segment index.
  final int selectedIndex;

  /// Called with the tapped segment index.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: _Segment(
                label: segments[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final style = theme.textTheme.labelLarge?.copyWith(
      color: selected ? scheme.onPrimary : scheme.onSurface,
    );

    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Text(label,
                style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
