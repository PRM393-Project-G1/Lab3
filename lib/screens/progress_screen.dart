import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/progress_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/analysis_stepper.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/info_banner.dart';
import '../widgets/state_view.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  void _leave(BuildContext context) {
    context.canPop() ? context.pop() : context.go(AppRoutes.analyze);
  }

  Future<void> _stop(BuildContext context, ProgressViewModel vm) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Stop analysis?',
      message: 'Progress will be lost.',
      confirmLabel: 'Stop',
      cancelLabel: 'Keep going',
      destructive: true,
    );
    if (!confirmed) return;
    final stopped = await vm.stop();
    if (!context.mounted) return;
    if (stopped) {
      _leave(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Can't reach server")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProgressViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: vm.isDone ? 'Done' : 'Analyzing…',
        onBack: () => _leave(context),
      ),
      body: switch (vm.state) {
        Failure() => StateView.error(onAction: () => _leave(context)),
        _ => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(
              vm.analysis?.displayTitle ?? 'arXiv:${vm.analysisId}',
              style: context.text.titleLarge,
            ),
            Text('arXiv:${vm.analysisId}', style: context.mono),
            const SizedBox(height: AppSpacing.md),
            if (vm.isOffline && !vm.isDone) ...[
              const InfoBanner(
                tone: BannerTone.offline,
                title: 'Offline · will resume',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (vm.isFailed) ...[
              InfoBanner(
                tone: BannerTone.error,
                title: 'Analysis failed',
                message: vm.failureReason,
                actions: [
                  AppButton(
                    'Retry',
                    variant: AppButtonVariant.text,
                    loading: vm.busy,
                    onPressed: vm.retry,
                  ),
                  AppButton(
                    'Edit',
                    variant: AppButtonVariant.text,
                    onPressed: () => context.go(AppRoutes.analyze),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (vm.commandFailed) ...[
              const InfoBanner(
                tone: BannerTone.error,
                title: "Can't reach server",
                message: 'Check Tailscale and backend.',
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LinearProgressIndicator(value: vm.fraction),
            const SizedBox(height: AppSpacing.xs),
            Text(vm.refsLabel, style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AnalysisStepper(
              steps: [
                for (final step in vm.steps)
                  AnalysisStep(step.label, switch (step.state) {
                    ProgressStepState.pending => AnalysisStepStatus.pending,
                    ProgressStepState.active => AnalysisStepStatus.active,
                    ProgressStepState.done => AnalysisStepStatus.done,
                    ProgressStepState.failed => AnalysisStepStatus.failed,
                  }),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (vm.isDone)
              AppButton(
                'View results',
                expand: true,
                onPressed: () =>
                    context.pushReplacement(AppRoutes.overview(vm.analysisId)),
              )
            else if (!vm.isFailed) ...[
              AppButton(
                'Run in background',
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => _leave(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                'Stop',
                variant: AppButtonVariant.text,
                expand: true,
                loading: vm.busy,
                onPressed: () => _stop(context, vm),
              ),
            ],
          ],
        ),
      },
    );
  }
}
