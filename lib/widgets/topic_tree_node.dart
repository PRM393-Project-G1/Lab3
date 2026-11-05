import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'status_bar.dart';
import 'weak_tag.dart';

/// One topic row: name, reference count, status bar and the Weak tag.
///
/// A null [expanded] means a leaf, so there is no chevron. [note] explains a
/// special row, for example "No readable text" on the Unclassified group.
class TopicTreeNode extends StatelessWidget {
  const TopicTreeNode({
    super.key,
    required this.name,
    required this.counts,
    this.depth = 0,
    this.isWeak = false,
    this.expanded,
    this.onToggle,
    this.onTap,
    this.note,
  });

  /// Deeper levels are opened on their own screen, so indentation stops here.
  static const maxIndentLevel = 3;

  final String name;
  final StatusCounts counts;
  final int depth;
  final bool isWeak;
  final bool? expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final indent = depth.clamp(0, maxIndentLevel) * AppSpacing.md;
    final refs = '${counts.total} refs';
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$name, $refs${isWeak ? ', weak topic' : ''}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.sm + indent,
            right: AppSpacing.md,
            top: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: AppSizes.minTap,
                child: expanded == null
                    ? null
                    : IconButton(
                        tooltip: expanded! ? 'Collapse' : 'Expand',
                        onPressed: onToggle,
                        icon: Icon(
                          expanded!
                              ? Icons.expand_more_rounded
                              : Icons.chevron_right_rounded,
                        ),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      style: depth == 0
                          ? context.text.titleLarge
                          : context.text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(refs, style: context.text.bodyMedium),
                        if (isWeak) const WeakTag(),
                      ],
                    ),
                    if (note != null)
                      Text(note!, style: context.text.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    StatusBar(counts),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
