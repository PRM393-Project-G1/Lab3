import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// One received notification. Unread items show a dot and say so to TalkBack.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.unread = false,
    this.onTap,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '${unread ? 'Unread: ' : ''}$title, $body, $timeLabel',
    excludeSemantics: true,
    child: AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: context.text.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  timeLabel,
                  style: context.text.labelSmall?.copyWith(
                    color: context.muted,
                  ),
                ),
              ],
            ),
          ),
          if (unread)
            Container(
              width: AppSizes.unreadDot,
              height: AppSizes.unreadDot,
              margin: const EdgeInsets.only(
                left: AppSpacing.sm,
                top: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    ),
  );
}
