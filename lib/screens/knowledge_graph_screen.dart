import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../firebase/ai_service.dart';
import '../models/knowledge_graph.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/knowledge_graph_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/knowledge_graph_view.dart';
import '../widgets/section_label.dart';
import '../widgets/state_view.dart';
import '../widgets/status_bar.dart';
import '../widgets/weak_tag.dart';

class KnowledgeGraphScreen extends StatelessWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KnowledgeGraphViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Knowledge graph', subtitle: vm.paperTitle),
      body: switch (vm.state) {
        Loading() => const Center(child: CircularProgressIndicator()),
        Failure() => StateView.error(onAction: vm.load),
        Empty() => const StateView.empty(
          icon: Icons.hub_outlined,
          title: 'Nothing here',
        ),
        Data(:final value) => _GraphBody(vm: vm, graph: value),
      },
    );
  }
}

class _GraphBody extends StatelessWidget {
  const _GraphBody({required this.vm, required this.graph});

  final KnowledgeGraphViewModel vm;
  final KnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    final edges = vm.visibleEdges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (graph.hasRelated)
                AppFilterChip(
                  label: 'Related',
                  selected: vm.showRelated,
                  onSelected: vm.setShowRelated,
                ),
              if (graph.hasAuthors)
                AppFilterChip(
                  label: 'Authors',
                  selected: vm.showAuthors,
                  onSelected: vm.setShowAuthors,
                ),
            ],
          ),
        ),
        _GeminiStatus(vm: vm),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.symmetric(
                horizontal: BorderSide(color: context.colors.outlineVariant),
              ),
            ),
            child: ClipRect(
              child: KnowledgeGraphView(
                graph: graph,
                nodes: vm.visibleNodes,
                edges: edges,
                highlighted: vm.highlighted,
                selectedId: vm.selectedId,
                onBackgroundTap: () => vm.select(null),
                onNodeTap: (id) => _openNode(context, vm, id),
              ),
            ),
          ),
        ),
        _Legend(
          showWeak: vm.visibleNodes.any((n) => n.isWeak),
          showAuthors: vm.showAuthors && graph.hasAuthors,
          kinds: {for (final edge in edges) edge.kind},
        ),
      ],
    );
  }
}

/// Selects the node and shows what it links to. Tapping a linked node in the
/// sheet moves to that node.
Future<void> _openNode(
  BuildContext context,
  KnowledgeGraphViewModel vm,
  String id,
) async {
  vm.select(id);
  final details = vm.details(id);
  if (details == null) return;
  final next = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (sheetContext) => _NodeSheet(
      details: details,
      onOpenTopic: () {
        Navigator.of(sheetContext).pop();
        context.push(AppRoutes.topic(vm.analysisId, id));
      },
    ),
  );
  if (next != null && context.mounted) await _openNode(context, vm, next);
}

class _GeminiStatus extends StatelessWidget {
  const _GeminiStatus({required this.vm});

  final KnowledgeGraphViewModel vm;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium;
    final count = vm.relations.length;
    final (
      Widget icon,
      String text,
      Widget? action,
    ) = switch (vm.relationsStatus) {
      RelationsStatus.loading => (
        const SizedBox.square(
          dimension: AppSizes.spinnerSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        'Gemini is naming relations…',
        null,
      ),
      RelationsStatus.failed => (
        Icon(
          Icons.error_outline_rounded,
          size: AppSizes.iconSm,
          color: context.colors.error,
        ),
        switch (vm.failure) {
          AiFailure.busy => 'Gemini is busy. Try again in a minute',
          AiFailure.quota => "Gemini's free limit is used up. Try later",
          AiFailure.timeout => 'Gemini took too long',
          _ => "Couldn't name relations",
        },
        TextButton(onPressed: vm.labelRelations, child: const Text('Retry')),
      ),
      RelationsStatus.ready => (
        Icon(
          Icons.auto_awesome_outlined,
          size: AppSizes.iconSm,
          color: context.colors.onSurfaceVariant,
        ),
        count == 0
            ? 'Gemini found no clear relations'
            : '$count ${count == 1 ? 'relation' : 'relations'} by Gemini · may be wrong',
        null,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTap),
        child: Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(text, style: style),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showWeak,
    required this.showAuthors,
    required this.kinds,
  });

  final bool showWeak;
  final bool showAuthors;
  final Set<GraphEdgeKind> kinds;

  static const _edgeLabels = {
    GraphEdgeKind.subtopic: 'Subtopic',
    GraphEdgeKind.related: 'Related',
    GraphEdgeKind.author: 'Writes about',
    GraphEdgeKind.isA: 'Is a',
    GraphEdgeKind.partOf: 'Part of',
    GraphEdgeKind.sameAs: 'Same as',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.graph;
    final style = context.text.labelSmall?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(label, style: style)),
      ],
    );
    Widget dot({required Color fill, Color? ring, bool square = false}) =>
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            shape: square ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: square ? BorderRadius.circular(3) : null,
            border: ring == null ? null : Border.all(color: ring, width: 2),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          item(dot(fill: colors.topic), 'Topic, sized by references'),
          if (showWeak)
            item(dot(fill: colors.topic, ring: colors.weak), 'Weak'),
          if (showAuthors)
            item(dot(fill: colors.author, square: true), 'Author'),
          for (final kind in GraphEdgeKind.values)
            if (kinds.contains(kind))
              item(GraphEdgeSwatch(kind), _edgeLabels[kind]!),
        ],
      ),
    );
  }
}

class _NodeSheet extends StatelessWidget {
  const _NodeSheet({required this.details, required this.onOpenTopic});

  final NodeDetails details;
  final VoidCallback onOpenTopic;

  @override
  Widget build(BuildContext context) {
    final node = details.node;
    final isTopic = node.kind == GraphNodeKind.topic;
    final named = [
      ('Is a kind of', details.broader),
      ('Kinds', details.narrower),
      ('Part of', details.partOf),
      ('Has parts', details.parts),
      ('Same as', details.sameAs),
    ].where((group) => group.$2.isNotEmpty).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(node.label, style: context.text.titleLarge),
                ),
                if (node.isWeak) const WeakTag(),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isTopic
                  ? '${node.weight} ${node.weight == 1 ? 'reference' : 'references'}'
                  : 'Author · ${node.weight} ${node.weight == 1 ? 'topic' : 'topics'}',
              style: context.text.bodyMedium,
            ),
            if (isTopic && node.counts.total > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusBar(node.counts),
            ],
            if (details.parent != null || details.subtopics.isNotEmpty) ...[
              const SectionLabel('Topic tree'),
              if (details.parent case final parent?)
                _Links(label: 'Under', nodes: [parent]),
              if (details.subtopics.isNotEmpty)
                _Links(label: 'Subtopics', nodes: details.subtopics),
            ],
            if (named.isNotEmpty) ...[
              const SectionLabel('Named by Gemini'),
              for (final (label, nodes) in named)
                _Links(label: label, nodes: nodes),
            ],
            if (details.related.isNotEmpty) ...[
              const SectionLabel('Found together in references'),
              _Links(nodes: details.related),
            ],
            if (details.authors.isNotEmpty) ...[
              const SectionLabel('Authors'),
              _Links(nodes: details.authors),
            ],
            if (details.topics.isNotEmpty) ...[
              const SectionLabel('Topics'),
              _Links(nodes: details.topics),
            ],
            if (isTopic) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                'Open topic',
                icon: Icons.arrow_forward_rounded,
                expand: true,
                onPressed: onOpenTopic,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Linked nodes as chips; tapping one closes the sheet with its id.
class _Links extends StatelessWidget {
  const _Links({required this.nodes, this.label});

  final String? label;
  final List<GraphNode> nodes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(label!, style: context.text.bodyMedium),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final node in nodes)
              ActionChip(
                avatar: node.kind == GraphNodeKind.author
                    ? const Icon(Icons.person_outline_rounded)
                    : null,
                label: Text(node.label),
                onPressed: () => Navigator.of(context).pop(node.id),
              ),
          ],
        ),
      ],
    ),
  );
}
