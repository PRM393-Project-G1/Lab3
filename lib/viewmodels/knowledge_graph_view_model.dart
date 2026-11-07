import 'dart:async';

import '../firebase/ai_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/knowledge_graph.dart';
import '../models/topic_relation.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

enum RelationsStatus { loading, ready, failed }

/// What the sheet shows for one node. Lists hold every link, whatever the
/// filters show on the graph.
class NodeDetails {
  const NodeDetails({
    required this.node,
    this.parent,
    this.subtopics = const [],
    this.broader = const [],
    this.narrower = const [],
    this.partOf = const [],
    this.parts = const [],
    this.sameAs = const [],
    this.related = const [],
    this.authors = const [],
    this.topics = const [],
  });

  final GraphNode node;
  final GraphNode? parent;
  final List<GraphNode> subtopics;

  /// Topics this one is a kind of.
  final List<GraphNode> broader;

  /// Kinds of this topic.
  final List<GraphNode> narrower;
  final List<GraphNode> partOf;
  final List<GraphNode> parts;
  final List<GraphNode> sameAs;
  final List<GraphNode> related;
  final List<GraphNode> authors;

  /// Topics of an author.
  final List<GraphNode> topics;
}

class KnowledgeGraphViewModel extends BaseViewModel {
  KnowledgeGraphViewModel({
    required this._analyses,
    required this._remoteConfig,
    required this._ai,
    required this._crashlytics,
    required this.analysisId,
  }) {
    load();
  }

  /// Topics sent to Gemini, the largest first. Keeps the prompt short.
  static const maxTerms = 60;

  final String analysisId;
  final AnalysisRepository _analyses;
  final RemoteConfigService _remoteConfig;
  final AiService _ai;
  final CrashlyticsService _crashlytics;

  ViewState<KnowledgeGraph> _state = const Loading();
  RelationsStatus _relationsStatus = RelationsStatus.loading;
  AiFailure? _failure;
  List<TopicRelation> _relations = const [];
  String? _paperTitle;
  String? _selectedId;
  bool _showRelated = true;
  bool _showAuthors = false;

  ViewState<KnowledgeGraph> get state => _state;
  RelationsStatus get relationsStatus => _relationsStatus;

  /// Why the last request failed, when [relationsStatus] is failed.
  AiFailure? get failure => _failure;
  String? get paperTitle => _paperTitle;
  String? get selectedId => _selectedId;
  bool get showRelated => _showRelated;
  bool get showAuthors => _showAuthors;

  /// Matched to topic ids.
  List<TopicRelation> get relations => _relations;

  KnowledgeGraph? get graph => _state.valueOrNull;

  List<GraphNode> get visibleNodes => [
    for (final node in graph?.nodes ?? const <GraphNode>[])
      if (node.kind == GraphNodeKind.topic || _showAuthors) node,
  ];

  List<GraphEdge> get visibleEdges => [
    for (final edge in graph?.edges ?? const <GraphEdge>[])
      if (switch (edge.kind) {
        GraphEdgeKind.related => _showRelated,
        GraphEdgeKind.author => _showAuthors,
        _ => true,
      })
        edge,
    ..._relationEdges,
  ];

  /// The selected node and the nodes it links to on screen; empty when nothing
  /// is selected.
  Set<String> get highlighted {
    final id = _selectedId;
    if (id == null) return const {};
    return {
      id,
      for (final edge in visibleEdges)
        if (edge.from == id) edge.to else if (edge.to == id) edge.from,
    };
  }

  Iterable<GraphEdge> get _relationEdges =>
      _relations.map((r) => GraphEdge(r.from, r.to, GraphEdgeKind.of(r.kind)));

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      final results = await _analyses.getResults(analysisId);
      _paperTitle = results.analysis?.displayTitle;
      if (results.topics.isEmpty) {
        _state = const Empty();
        notifyListeners();
        return;
      }
      final tree = results.tree(_remoteConfig.weakTopicRule);
      _state = Data(KnowledgeGraph.build(tree));
      notifyListeners();
    } catch (_) {
      _state = const Failure.loadFailed();
      notifyListeners();
      return;
    }
    await labelRelations();
  }

  /// Asks Gemini to name the relations between the topics. The graph works
  /// without them, so a failure only shows a retry.
  Future<void> labelRelations() async {
    final graph = this.graph;
    if (graph == null) return;
    _relationsStatus = RelationsStatus.loading;
    _failure = null;
    notifyListeners();

    final topics =
        graph.nodes.where((n) => n.kind == GraphNodeKind.topic).toList()
          ..sort((a, b) {
            final byWeight = b.weight.compareTo(a.weight);
            if (byWeight != 0) return byWeight;
            final byDepth = a.depth.compareTo(b.depth);
            return byDepth != 0 ? byDepth : a.label.compareTo(b.label);
          });
    final idOf = <String, String>{};
    final terms = <String>[];
    for (final node in topics) {
      final key = node.label.trim().toLowerCase();
      if (key.isEmpty || idOf.containsKey(key)) continue;
      idOf[key] = node.id;
      terms.add(node.label);
      if (terms.length == maxTerms) break;
    }

    try {
      final found = terms.length < 2
          ? const <TopicRelation>[]
          : await _ai.relateTerms(
              terms,
              model: _remoteConfig.geminiModel,
              paperTitle: _paperTitle,
            );
      _relations = [
        for (final relation in found)
          if (idOf[relation.from.trim().toLowerCase()] case final from?)
            if (idOf[relation.to.trim().toLowerCase()] case final to?)
              if (from != to) TopicRelation(from, to, relation.kind),
      ];
      _relationsStatus = RelationsStatus.ready;
    } catch (error, stack) {
      _relationsStatus = RelationsStatus.failed;
      _failure = error is AiException ? error.failure : AiFailure.other;
      unawaited(
        _crashlytics.recordNonFatal(error, stack, reason: 'gemini_relations'),
      );
    }
    notifyListeners();
  }

  /// Null clears the selection.
  void select(String? id) {
    _selectedId = id != null && graph?.byId[id] != null ? id : null;
    if (_selectedId != null &&
        graph!.byId[_selectedId]!.kind == GraphNodeKind.author) {
      _showAuthors = true;
    }
    notifyListeners();
  }

  void setShowRelated(bool value) {
    _showRelated = value;
    notifyListeners();
  }

  void setShowAuthors(bool value) {
    _showAuthors = value;
    if (!value && graph?.byId[_selectedId]?.kind == GraphNodeKind.author) {
      _selectedId = null;
    }
    notifyListeners();
  }

  NodeDetails? details(String id) {
    final graph = this.graph;
    final node = graph?.byId[id];
    if (graph == null || node == null) return null;
    final edges = [...graph.edges, ..._relationEdges];

    List<GraphNode> linked(GraphEdgeKind kind, {bool? outgoing}) => [
      for (final edge in edges)
        if (edge.kind == kind)
          if (edge.from == id && outgoing != false)
            ?graph.byId[edge.to]
          else if (edge.to == id && outgoing != true)
            ?graph.byId[edge.from],
    ];

    final parents = linked(GraphEdgeKind.subtopic, outgoing: true);
    return NodeDetails(
      node: node,
      parent: parents.isEmpty ? null : parents.first,
      subtopics: linked(GraphEdgeKind.subtopic, outgoing: false),
      broader: linked(GraphEdgeKind.isA, outgoing: true),
      narrower: linked(GraphEdgeKind.isA, outgoing: false),
      partOf: linked(GraphEdgeKind.partOf, outgoing: true),
      parts: linked(GraphEdgeKind.partOf, outgoing: false),
      sameAs: linked(GraphEdgeKind.sameAs),
      related: linked(GraphEdgeKind.related),
      authors: linked(GraphEdgeKind.author, outgoing: false),
      topics: linked(GraphEdgeKind.author, outgoing: true),
    );
  }
}
