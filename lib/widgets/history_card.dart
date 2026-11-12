import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'status_bar.dart';
import 'status_chip.dart';

enum HistoryCardState { done, running, failed, removed }

/// One past or running analysis.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.title,
    required this.arxivId,
    required this.timeLabel,
    this.state = HistoryCardState.done,
    this.counts,
    this.onTap,
    this.onRename,
    this.onDelete,
    this.compact = false,
  });

  final String title;
  final String arxivId;
  final String timeLabel;
  final HistoryCardState state;
  final StatusCounts? counts;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasMenu = onRename != null || onDelete != null;
    return Semantics(
      button: onTap != null,
      label: title,
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('arXiv:$arxivId', style: context.mono),
                          Text(timeLabel, style: context.text.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasMenu)
                  PopupMenuButton<VoidCallback>(
                    tooltip: 'More actions',
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      if (onRename != null)
                        PopupMenuItem(
                          value: onRename,
                          child: const Text('Rename'),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: onDelete,
                          child: const Text('Delete'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            switch (state) {
              HistoryCardState.running => const StatusChip(
                RefStatus.unverified,
                label: 'Running',
                icon: Icons.sync_rounded,
              ),
              HistoryCardState.removed => const StatusChip(
                RefStatus.unverified,
                label: 'Removed',
                icon: Icons.visibility_off_rounded,
              ),
              HistoryCardState.failed => const StatusChip(
                RefStatus.error,
                label: 'Failed',
              ),
              HistoryCardState.done =>
                counts == null
                    ? const SizedBox.shrink()
                    : StatusBar(counts!, showLegend: !compact),
            },
          ],
        ),
      ),
    );
  }
}
