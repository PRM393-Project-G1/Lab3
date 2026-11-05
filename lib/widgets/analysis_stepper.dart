import 'package:flutter/material.dart';

import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

enum AnalysisStepStatus { pending, active, done, failed }

class AnalysisStep {
  const AnalysisStep(this.label, this.status);

  final String label;
  final AnalysisStepStatus status;
}

/// Vertical list of the analysis steps. Step names only, no descriptions.
class AnalysisStepper extends StatelessWidget {
  const AnalysisStepper({super.key, required this.steps});

  final List<AnalysisStep> steps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < steps.length; i++)
        _StepRow(step: steps[i], isLast: i == steps.length - 1),
    ],
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});

  final AnalysisStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusName = switch (step.status) {
      AnalysisStepStatus.pending => 'Pending',
      AnalysisStepStatus.active => 'In progress',
      AnalysisStepStatus.done => 'Done',
      AnalysisStepStatus.failed => 'Failed',
    };
    final Widget indicator = switch (step.status) {
      AnalysisStepStatus.pending => Icon(
        Icons.radio_button_unchecked_rounded,
        color: colors.outline,
      ),
      AnalysisStepStatus.active => const Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      AnalysisStepStatus.done => Icon(
        Icons.check_circle_rounded,
        color: context.status(RefStatus.verified).icon,
      ),
      AnalysisStepStatus.failed => Icon(
        Icons.error_rounded,
        color: colors.error,
      ),
    };

    return Semantics(
      label: '${step.label}: $statusName',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                SizedBox.square(dimension: AppSizes.iconMd, child: indicator),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: colors.outlineVariant),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                child: Text(
                  step.label,
                  style: step.status == AnalysisStepStatus.active
                      ? context.text.titleMedium
                      : context.text.bodyLarge?.copyWith(
                          color: step.status == AnalysisStepStatus.pending
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
