import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

enum BannerTone { fabricated, error, warning, success, info, offline }

/// Inline message for alerts and recoverable problems, with optional actions.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.actions = const [],
  });

  final BannerTone tone;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (foreground, iconColor, container, border, icon) = _style(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: container,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (message != null)
                        Text(
                          message!,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color, Color, Color, IconData) _style(BuildContext context) {
    (Color, Color, Color, Color, IconData) tier(
      RefStatus status,
      IconData icon,
    ) {
      final t = context.status(status);
      return (t.foreground, t.icon, t.container, t.border, icon);
    }

    final colors = context.colors;
    return switch (tone) {
      BannerTone.fabricated => tier(
        RefStatus.hallucinated,
        Icons.gpp_bad_rounded,
      ),
      BannerTone.error => tier(RefStatus.error, Icons.error_rounded),
      BannerTone.warning => tier(
        RefStatus.warning,
        Icons.warning_amber_rounded,
      ),
      BannerTone.success => tier(
        RefStatus.verified,
        Icons.check_circle_rounded,
      ),
      BannerTone.offline => tier(RefStatus.unverified, Icons.cloud_off_rounded),
      BannerTone.info => (
        colors.primary,
        colors.primary,
        colors.primaryContainer,
        colors.primaryContainer,
        Icons.info_rounded,
      ),
    };
  }
}
