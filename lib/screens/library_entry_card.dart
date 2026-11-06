import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/library_entry.dart';
import '../utils/time_format.dart';
import '../widgets/history_card.dart';

/// A history card for one entry. Running work opens the progress screen.
class LibraryEntryCard extends StatelessWidget {
  const LibraryEntryCard({
    super.key,
    required this.entry,
    this.compact = false,
    this.onOpen,
    this.onRename,
    this.onDelete,
  });

  final LibraryEntry entry;
  final bool compact;
  final VoidCallback? onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  HistoryCardState get _state {
    final analysis = entry.analysis;
    if (analysis?.isRunning ?? false) return HistoryCardState.running;
    if (analysis?.isStopped ?? false) return HistoryCardState.failed;
    return HistoryCardState.done;
  }

  @override
  Widget build(BuildContext context) => HistoryCard(
    title: entry.title,
    arxivId: entry.arxivId,
    timeLabel: timeAgo(entry.sortTime),
    state: _state,
    counts: entry.analysis?.counts,
    compact: compact,
    onRename: onRename,
    onDelete: onDelete,
    onTap: () {
      onOpen?.call();
      context.push(
        _state == HistoryCardState.done
            ? '/analyses/${entry.arxivId}'
            : '/analyses/${entry.arxivId}/progress',
      );
    },
  );
}
