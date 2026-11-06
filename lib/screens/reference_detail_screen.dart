import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/ref_status.dart';
import '../models/reference.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/reference_detail_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/cited_actual_table.dart';
import '../widgets/info_banner.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';

class ReferenceDetailScreen extends StatelessWidget {
  const ReferenceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReferenceDetailViewModel>();
    if (vm.takeFabricationPrompt()) {
      final ref = vm.state.valueOrNull!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showFabricationDialog(context, vm, ref);
      });
    }
    return Scaffold(
      appBar: const AppTopBar(title: 'Reference'),
      body: switch (vm.state) {
        Loading() || Empty() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Data(:final value) => _Content(vm: vm, reference: value),
      },
    );
  }
}

Future<void> _showFabricationDialog(
  BuildContext context,
  ReferenceDetailViewModel vm,
  Reference ref,
) async {
  final closestUrl = ref.closestMatchUrl;
  final action = await showDialog<_FabricationAction>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: 'Likely fabricated',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ref.hallucinationNote != null) Text(ref.hallucinationNote!),
          if (ref.closestMatchTitle != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Closest match', style: context.text.titleMedium),
            Text(ref.closestMatchTitle!),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'May be wrong — check the source.',
            style: context.text.bodyMedium,
          ),
        ],
      ),
      confirmLabel: closestUrl == null ? 'Search web' : 'Open',
      cancelLabel: closestUrl == null ? 'Close' : 'Search web',
      onConfirm: () => Navigator.of(dialogContext).pop(
        closestUrl == null
            ? _FabricationAction.search
            : _FabricationAction.open,
      ),
      onCancel: () =>
          Navigator.of(dialogContext)
              .pop(closestUrl == null ? null : _FabricationAction.search),
    ),
  );
  switch (action) {
    case _FabricationAction.open:
      await vm.openUrl(closestUrl!);
    case _FabricationAction.search:
      await vm.searchWeb(ref);
    case null:
      break;
  }
}

enum _FabricationAction { open, search }

class _Content extends StatelessWidget {
  const _Content({required this.vm, required this.reference});

  final ReferenceDetailViewModel vm;
  final Reference reference;

  BannerTone get _tone => switch (reference.status) {
    RefStatus.hallucinated => BannerTone.fabricated,
    RefStatus.error => BannerTone.error,
    RefStatus.warning => BannerTone.warning,
    RefStatus.unverified => BannerTone.info,
    RefStatus.verified => BannerTone.success,
  };

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    final comparable = ref.comparableIssues;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        InfoBanner(
          tone: _tone,
          title: ref.status == RefStatus.hallucinated
              ? 'Likely fabricated'
              : ref.status.label,
          message: ref.status == RefStatus.hallucinated
              ? ref.hallucinationNote
              : ref.firstIssue,
          actions: [
            if (ref.status == RefStatus.hallucinated)
              AppButton(
                'Details',
                variant: AppButtonVariant.text,
                onPressed: () => _showFabricationDialog(context, vm, ref),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(ref.title, style: context.text.titleLarge),
        if (ref.byline.isNotEmpty)
          Text(ref.byline, style: context.text.bodyMedium),
        if (comparable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          CitedActualTable(
            rows: [
              for (final issue in comparable)
                CitedActualRow(
                  field: issue.type,
                  cited: issue.cited!,
                  actual: issue.actual!,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            'Copy fix',
            variant: AppButtonVariant.secondary,
            icon: Icons.copy_rounded,
            expand: true,
            onPressed: () async {
              await vm.copyFix(ref);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Fix copied')));
            },
          ),
        ],
        if (vm.topics.isNotEmpty) ...[
          const SectionLabel('Topics'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final topic in vm.topics)
                ActionChip(
                  label: Text(topic.term),
                  onPressed: () => context.push(
                    '/analyses/${vm.analysisId}/topics/${topic.id}',
                  ),
                ),
            ],
          ),
        ],
        if (ref.url != null) ...[
          const SectionLabel('Source'),
          AppButton(
            'Open',
            variant: AppButtonVariant.text,
            icon: Icons.open_in_new_rounded,
            onPressed: () => vm.openUrl(ref.url!),
          ),
        ],
      ],
    );
  }
}
