import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/overview_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/info_banner.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';
import '../widgets/status_bar.dart';
import '../widgets/topic_tree_node.dart';
import 'export_flow.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  /// Opened from a push there is no history, so Back leads to History.
  void _back(BuildContext context) {
    context.canPop() ? context.pop() : context.go(AppRoutes.history);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OverviewViewModel>();
    final id = vm.analysisId;
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.history);
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Paper Overview',
          onBack: () => _back(context),
          actions: [
            if (vm.canExport && vm.state is Data)
              TextButton(
                onPressed: () => showExportSheet(context, id),
                child: const Text('Report'),
              ),
          ],
        ),
        body: switch (vm.state) {
          Loading() || Empty() => const SkeletonList(),
          Failure(:final message) when vm.unavailableMessage != null =>
            StateView.empty(
              icon: Icons.visibility_off_rounded,
              title: message,
              message: vm.unavailableMessage,
            ),
          Failure() => StateView.error(onAction: vm.load),
          Data(:final value) => _Content(id: id, data: value),
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.id, required this.data});

  final String id;
  final OverviewData data;

  void _review(BuildContext context, RefStatus status) {
    context.push(AppRoutes.references(id, filter: status.name));
  }

  @override
  Widget build(BuildContext context) {
    final analysis = data.analysis;
    final alert = data.alertStatus;
    final weak = data.weakTopics;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Text(analysis.displayTitle, style: context.text.titleLarge),
        if (analysis.authors.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(analysis.authors.join(', '), style: context.text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.md),
        if (alert != null) ...[
          InfoBanner(
            tone: alert == RefStatus.hallucinated
                ? BannerTone.fabricated
                : BannerTone.error,
            title: alert == RefStatus.hallucinated
                ? '${analysis.counts.hallucinated} may be fabricated'
                : '${analysis.counts.error} with errors',
            actions: [
              AppButton(
                'Review',
                variant: AppButtonVariant.text,
                onPressed: () => _review(context, alert),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'References (${analysis.totalRefs})',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusBar(
                analysis.counts,
                showLegend: true,
                onStatusTap: (status) => _review(context, status),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Topics', style: context.text.titleMedium),
              Text(
                '${data.topicCount} topics · ${weak.length} weak',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final node in weak)
                TopicTreeNode(
                  name: node.term,
                  counts: node.counts,
                  isWeak: true,
                  onTap: () => context.push(AppRoutes.topic(id, node.id)),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                'Explore',
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => context.push(AppRoutes.topics(id)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
