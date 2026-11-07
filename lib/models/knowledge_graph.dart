import 'dart:math' as math;
import 'dart:ui';

import '../utils/force_layout.dart';
import 'ref_status.dart';
import 'topic_relation.dart';
import 'topic_tree.dart';

enum GraphNodeKind { topic, author }

enum GraphEdgeKind {
  /// Child topic to its parent in the topic tree.
  subtopic,

  /// Topics Saffron finds in the same references.
  related,

  /// Author to a topic they write about.
  author,

  isA,
  partOf,
  sameAs;

  static GraphEdgeKind of(RelationKind kind) => switch (kind) {
    RelationKind.isA => isA,
    RelationKind.partOf => partOf,
    RelationKind.sameAs => sameAs,
  };

  /// Labelled by Gemini rather than read from Saffron.
  bool get isNamed => this == isA || this == partOf || this == sameAs;
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.kind,
    this.weight = 1,
    this.depth = 0,
    this.isWeak = false,
    this.counts = const StatusCounts(),
  });

  /// The topic id, or `author:` and the name.
  final String id;
  final String label;
  final GraphNodeKind kind;

  /// References under a topic, or topics of an author. Sets the node size.
  final int weight;
  final int depth;
  final bool isWeak;
  final StatusCounts counts;
}

class GraphEdge {
  const GraphEdge(this.from, this.to, this.kind);

  final String from;
  final String to;
  final GraphEdgeKind kind;

  bool touches(String id) => from == id || to == id;
}

/// The topics of one analysis as a graph, laid out once.
///
/// The layout uses only what Saffron found, so the nodes stay where they are
/// when Gemini's relations arrive.
class KnowledgeGraph {
  KnowledgeGraph._(this.nodes, this.edges, this.positions, this.size)
    : byId = {for (final node in nodes) node.id: node};

  factory KnowledgeGraph.build(TopicTree tree, {int maxAuthors = 15}) {
    final topics = tree.byId.values.toList();
    final nodes = <GraphNode>[
      for (final node in topics)
        GraphNode(
          id: node.id,
          label: node.term,
          kind: GraphNodeKind.topic,
          weight: node.counts.total,
          depth: node.depth,
          isWeak: node.isWeak,
          counts: node.counts,
        ),
    ];
    final edges = <GraphEdge>[
      for (final node in topics)
        if (node.parent case final parent?)
          GraphEdge(node.id, parent.id, GraphEdgeKind.subtopic),
    ];

    final linked = {for (final e in edges) _pair(e.from, e.to)};
    for (final node in topics) {
      for (final link in node.topic.related) {
        if (!tree.byId.containsKey(link.topicId)) continue;
        if (linked.add(_pair(node.id, link.topicId))) {
          edges.add(GraphEdge(node.id, link.topicId, GraphEdgeKind.related));
        }
      }
    }

    // Authors who write about the most topics, then with the highest scores.
    final topicsOf = <String, Set<String>>{};
    final scoreOf = <String, double>{};
    for (final node in topics) {
      for (final author in node.topic.authors) {
        topicsOf.putIfAbsent(author.name, () => {}).add(node.id);
        scoreOf[author.name] = (scoreOf[author.name] ?? 0) + author.score;
      }
    }
    final authors = topicsOf.keys.toList()
      ..sort((a, b) {
        final byTopics = topicsOf[b]!.length.compareTo(topicsOf[a]!.length);
        return byTopics != 0 ? byTopics : scoreOf[b]!.compareTo(scoreOf[a]!);
      });
    for (final name in authors.take(maxAuthors)) {
      final id = 'author:$name';
      nodes.add(
        GraphNode(
          id: id,
          label: name,
          kind: GraphNodeKind.author,
          weight: topicsOf[name]!.length,
        ),
      );
      for (final topicId in topicsOf[name]!) {
        edges.add(GraphEdge(id, topicId, GraphEdgeKind.author));
      }
    }

    final size = layoutSize(nodes.length);
    final positions = forceLayout(
      [for (final node in nodes) node.id],
      [for (final edge in edges) (edge.from, edge.to)],
      size: size,
    );
    return KnowledgeGraph._(nodes, edges, positions, size);
  }

  /// Taller than wide, like a phone, and larger as nodes are added.
  static Size layoutSize(int nodeCount) {
    final width = (40 * math.sqrt(nodeCount) + 160).clamp(320.0, 640.0);
    return Size(width, width * 1.6);
  }

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, GraphNode> byId;
  final Map<String, Offset> positions;
  final Size size;

  bool get hasAuthors => nodes.any((n) => n.kind == GraphNodeKind.author);
  bool get hasRelated => edges.any((e) => e.kind == GraphEdgeKind.related);

  static String _pair(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
}
