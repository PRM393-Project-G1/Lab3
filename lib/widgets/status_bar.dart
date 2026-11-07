import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'status_chip.dart';

/// Stacked bar of reference statuses. Its counts are exposed to screen readers;
/// [showLegend] also prints them, so the meaning never depends on colour alone.
class StatusBar extends StatelessWidget {
  const StatusBar(
    this.counts, {
    super.key,
    this.showLegend = false,
    this.onStatusTap,
  });

  final StatusCounts counts;
  final bool showLegend;
  final ValueChanged<RefStatus>? onStatusTap;

  String get _description => RefStatus.values
      .where((status) => counts.of(status) > 0)
      .map((status) => '${counts.of(status)} ${status.label}')
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final bar = Semantics(
      label: _description,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // A ColoredBox without a child takes the smallest size it may, so the
        // bar fixes both sides and the row stretches its segments to full height.
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.statusBarHeight,
          child: counts.total == 0
              ? ColoredBox(color: context.colors.surfaceContainerHigh)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final status in RefStatus.values)
                      if (counts.of(status) > 0)
                        Expanded(
                          flex: counts.of(status),
                          child: ColoredBox(color: context.status(status).icon),
                        ),
                  ],
                ),
        ),
      ),
    );
    if (!showLegend) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final status in RefStatus.values)
              if (counts.of(status) > 0)
                StatusChip(
                  status,
                  count: counts.of(status),
                  onTap: onStatusTap == null
                      ? null
                      : () => onStatusTap!(status),
                ),
          ],
        ),
      ],
    );
  }
}
