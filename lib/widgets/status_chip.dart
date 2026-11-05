import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

/// Status pill: icon + text + colour, never colour alone.
///
/// With [onTap] it grows to the minimum touch target.
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.status, {
    super.key,
    this.count,
    this.label,
    this.icon,
    this.onTap,
  });

  final RefStatus status;
  final int? count;

  /// Replaces the status name, for example "Running".
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = context.status(status);
    final name = label ?? status.label;
    final text = count == null ? name : '$count $name';
    final radius = BorderRadius.circular(AppRadius.sm);

    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tier.container,
        borderRadius: radius,
        border: Border.all(color: tier.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? status.icon, size: AppSizes.iconSm, color: tier.icon),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: context.text.labelSmall?.copyWith(color: tier.foreground),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: text, excludeSemantics: true, child: pill);
    }
    return Semantics(
      label: text,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTap,
            minWidth: AppSizes.minTap,
          ),
          child: Align(widthFactor: 1, heightFactor: 1, child: pill),
        ),
      ),
    );
  }
}
