import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Wraps a set of [SettingsRow]s (or any rows) in the shared [AppCard] with
/// hairline dividers between them — the grouped-list pattern GoRide uses for the
/// Account menu and the Settings sections. Pass the rows in order; dividers are
/// inserted automatically and inset to align with the row labels.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  /// Rows to stack inside the card.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outline;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(
          height: AppStroke.thin,
          thickness: AppStroke.thin,
          indent: AppSpacing.lg,
          endIndent: AppSpacing.lg,
          color: dividerColor,
        ));
      }
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
