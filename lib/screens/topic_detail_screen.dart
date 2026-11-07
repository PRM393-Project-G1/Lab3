import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/ref_status.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/topic_detail_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/reference_card.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';
import '../widgets/status_bar.dart';
import '../widgets/topic_tree_node.dart';
import '../widgets/weak_tag.dart';

class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TopicDetailViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'Topic'),
      body: switch (vm.state) {
        Loading() || Empty() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Data(:final value) => _Content(vm: vm, data: value),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.vm, required this.data});

  final TopicDetailViewModel vm;
  final TopicDetailData data;

  @override
  Widget build(BuildContext context) {
    final node = data.node;
    final id = vm.analysisId;
    final visible = vm.visibleReferences;
    final ancestors = node.path.map((n) => n.term).toList()..removeLast();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (ancestors.isNotEmpty) ...[
          Text(ancestors.join(' › '), style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(node.term, style: context.text.headlineMedium),
            if (node.isWeak) const WeakTag(),
          ],
        ),
        if (_stats(data) case final stats?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(stats, style: context.text.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.md),
        StatusBar(node.counts, showLegend: true),
        if (node.children.isNotEmpty) ...[
          const SectionLabel('Subtopics'),
          for (final child in node.children)
            TopicTreeNode(
              name: child.term,
              counts: child.counts,
              isWeak: child.isWeak,
              onTap: () => context.push(AppRoutes.topic(id, child.id)),
            ),
        ],
        if (data.related.isNotEmpty) ...[
          const SectionLabel('Related topics'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final other in data.related)
                ActionChip(
                  label: Text(other.term),
                  onPressed: () => context.push(AppRoutes.topic(id, other.id)),
                ),
            ],
          ),
        ],
        if (node.topic.authors.isNotEmpty) ...[
          const SectionLabel('Key authors'),
          for (final author in node.topic.authors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: AppSizes.iconSm,
                    color: context.muted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(author.name, style: context.text.bodyLarge),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            AppFilterChip(
              label: 'All',
              count: node.counts.total,
              selected: vm.filter == null,
              onSelected: (_) => vm.setFilter(null),
            ),
            for (final status in RefStatus.values)
              if (node.counts.of(status) > 0)
                AppFilterChip(
                  label: status.label,
                  count: node.counts.of(status),
                  selected: vm.filter == status,
                  onSelected: (_) => vm.setFilter(status),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visible.isEmpty)
          const StateView.empty(
            icon: Icons.filter_alt_off_outlined,
            title: 'Nothing here',
          ),
        for (final ref in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ReferenceCard(
              status: ref.status,
              title: ref.title,
              byline: ref.byline,
              issue: ref.firstIssue,
              onTap: () => context.push(AppRoutes.reference(id, ref.id)),
            ),
          ),
      ],
    );
  }
}

/// "31 mentions · #2 of 35 by Saffron score", or null for older analyses.
String? _stats(TopicDetailData data) {
  final rank = data.rank;
  final parts = [
    ?data.node.topic.mentions,
    if (rank != null) '#$rank of ${data.rankedCount} by Saffron score',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
