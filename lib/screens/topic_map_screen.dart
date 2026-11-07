import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/reference_list_view_model.dart';
import '../viewmodels/topic_map_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/ranked_bars.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';
import '../widgets/topic_tree_node.dart';

class TopicMapScreen extends StatelessWidget {
  const TopicMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TopicMapViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Topics',
        subtitle: vm.paperTitle,
        actions: [
          if (vm.state is Data)
            IconButton(
              tooltip: 'Knowledge graph',
              icon: const Icon(Icons.hub_outlined),
              onPressed: () => context.push('/analyses/${vm.analysisId}/graph'),
            ),
        ],
      ),
      body: switch (vm.state) {
        Loading() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Empty() => const StateView.empty(
          icon: Icons.account_tree_outlined,
          title: 'Nothing here',
        ),
        Data() => _Tree(vm: vm),
      },
    );
  }
}

class _Tree extends StatelessWidget {
  const _Tree({required this.vm});

  final TopicMapViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rows = vm.rows;
    final keyTopics = vm.keyTopics;
    final id = vm.analysisId;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        if (keyTopics.isNotEmpty) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Key topics', style: context.text.titleMedium),
                Text(
                  "Ranked by Saffron's term score",
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                RankedBars([
                  for (final node in keyTopics)
                    RankedBar(
                      label: node.term,
                      value: node.topic.importance,
                      valueLabel: node.topic.importance.toStringAsFixed(2),
                      caption: node.topic.mentions,
                      onTap: () =>
                          context.push('/analyses/$id/topics/${node.id}'),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            AppFilterChip(
              label: 'All',
              selected: !vm.weakOnly,
              onSelected: (_) => vm.setWeakOnly(false),
            ),
            AppFilterChip(
              label: 'Weak',
              selected: vm.weakOnly,
              onSelected: (_) => vm.setWeakOnly(true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (rows.isEmpty && vm.weakOnly)
          StateView.empty(
            icon: Icons.verified_outlined,
            title: 'No weak topics',
            actionLabel: 'Show all',
            onAction: () => vm.setWeakOnly(false),
          ),
        for (final row in rows)
          TopicTreeNode(
            name: row.node.term,
            counts: row.node.counts,
            depth: row.node.depth,
            isWeak: row.node.isWeak,
            expanded: row.expanded,
            onToggle: () => vm.toggle(row.node.id),
            onTap: () => context.push('/analyses/$id/topics/${row.node.id}'),
          ),
        if (vm.unclassifiedCount > 0 && !vm.weakOnly)
          TopicTreeNode(
            name: 'Unclassified · ${vm.unclassifiedCount}',
            counts: vm.unclassifiedCounts,
            note: 'No readable text',
            onTap: () => context.push(
              '/analyses/$id/references?filter=${ReferenceFilter.unclassified.key}',
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Weak: ≥ ${vm.weakPercent}% refs have issues',
          style: context.text.bodyMedium,
        ),
      ],
    );
  }
}
