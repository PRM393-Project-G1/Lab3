import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

enum ExportStage { creating, uploading, uploaded, saved, failed }

/// Content of the "Export report" bottom sheet, one layout per stage.
class ExportSheet extends StatelessWidget {
  const ExportSheet({
    super.key,
    required this.stage,
    this.progress = 0,
    this.fileLabel,
    this.onCopyLink,
    this.onOpen,
    this.onShare,
    this.onRetry,
  });

  final ExportStage stage;

  /// Upload progress from 0 to 1.
  final double progress;

  /// Mono file line, for example "realtron_1706.03762.pdf · 214 KB".
  final String? fileLabel;
  final VoidCallback? onCopyLink;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    final title = switch (stage) {
      ExportStage.creating => 'Creating PDF…',
      ExportStage.uploading => 'Uploading $percent%',
      ExportStage.uploaded => 'Uploaded',
      ExportStage.saved => 'Saved on device',
      ExportStage.failed => 'Export failed',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Export report', style: context.text.titleLarge),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(child: _indicator(context)),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
            ),
            if (fileLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                fileLabel!,
                textAlign: TextAlign.center,
                style: context.mono,
              ),
            ],
            if (stage == ExportStage.uploading) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: progress),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (stage == ExportStage.uploaded || stage == ExportStage.saved)
              Row(
                children: [
                  Expanded(
                    child: stage == ExportStage.uploaded
                        ? AppButton(
                            'Copy link',
                            onPressed: onCopyLink,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.link_rounded,
                          )
                        : AppButton(
                            'Open',
                            onPressed: onOpen,
                            variant: AppButtonVariant.secondary,
                            icon: Icons.open_in_new_rounded,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      'Share',
                      onPressed: onShare,
                      icon: Icons.share_rounded,
                    ),
                  ),
                ],
              ),
            if (stage == ExportStage.failed)
              AppButton(
                'Retry',
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                expand: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _indicator(BuildContext context) => switch (stage) {
    ExportStage.creating || ExportStage.uploading => const SizedBox.square(
      dimension: AppSizes.iconLg,
      child: CircularProgressIndicator(),
    ),
    ExportStage.uploaded || ExportStage.saved => Icon(
      Icons.check_circle_rounded,
      size: AppSizes.iconLg,
      color: context.status(RefStatus.verified).icon,
    ),
    ExportStage.failed => Icon(
      Icons.error_rounded,
      size: AppSizes.iconLg,
      color: context.colors.error,
    ),
  };
}
