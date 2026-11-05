import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// One reference in a list. The whole card is the touch target.
class ReferenceCard extends StatelessWidget {
  const ReferenceCard({
    super.key,
    required this.status,
    required this.title,
    required this.byline,
    this.issue,
    this.onTap,
    this.compact = false,
  });

  final RefStatus status;
  final String title;

  /// First author and year, for example "Graves · 2013".
  final String byline;

  /// One-line problem; omitted for verified references.
  final String? issue;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = context.status(status);
    return Semantics(
      button: onTap != null,
      label: '${status.label}: $title',
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(status),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(byline, style: context.text.bodyMedium),
            if (issue != null && !compact) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tier.container,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  issue!,
                  style: context.text.bodyMedium?.copyWith(
                    color: tier.foreground,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
