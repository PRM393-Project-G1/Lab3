import 'ref_status.dart';
import 'reference.dart';
import 'topic.dart';

/// A topic with its place in the tree and the totals of its whole subtree.
class TopicNode {
  TopicNode(this.topic);

  final Topic topic;
  final List<TopicNode> children = [];
  TopicNode? parent;

  /// References of this topic and every topic below it, each counted once.
  Set<String> refIds = {};
  StatusCounts counts = const StatusCounts();
  bool isWeak = false;

  String get id => topic.id;
  String get term => topic.term;
  int get depth => parent == null ? 0 : parent!.depth + 1;

  /// From the root down to this node.
  List<TopicNode> get path => [...?parent?.path, this];

  bool get hasWeakBelow =>
      children.any((child) => child.isWeak || child.hasWeakBelow);
}

/// The flat topic list from Firestore, arranged as a tree.
class TopicTree {
  TopicTree._(this.roots, this.byId, this.weak);

  factory TopicTree.build({
    required List<Topic> topics,
    required List<Reference> references,
    required double weakThreshold,
    required int weakMinRefs,
  }) {
    final byId = {for (final topic in topics) topic.id: TopicNode(topic)};
    final roots = <TopicNode>[];
    for (final node in byId.values) {
      final parent = byId[node.topic.parentId];
      if (parent == null || parent == node) {
        roots.add(node);
      } else {
        node.parent = parent;
        parent.children.add(node);
      }
    }

    final statuses = {for (final ref in references) ref.id: ref.status};
    final weak = <TopicNode>[];
    void rollUp(TopicNode node) {
      node.refIds = {...node.topic.refIds};
      for (final child in node.children) {
        rollUp(child);
        node.refIds.addAll(child.refIds);
      }
      node.counts = _count(node, statuses);
      node.isWeak = _isWeak(node.counts, weakThreshold, weakMinRefs);
      if (node.isWeak) weak.add(node);
      node.children.sort(_byIssuesThenSize);
    }

    roots.forEach(rollUp);
    roots.sort(_byIssuesThenSize);
    weak.sort(_byIssuesThenSize);
    return TopicTree._(roots, byId, weak);
  }

  final List<TopicNode> roots;
  final Map<String, TopicNode> byId;

  /// Weak topics, most issues first.
  final List<TopicNode> weak;

  static StatusCounts _count(TopicNode node, Map<String, RefStatus> statuses) {
    // Older results may hold counts without the reference documents.
    if (statuses.isEmpty) return node.topic.counts;
    return StatusCounts.fromStatuses(
      node.refIds.map((id) => statuses[id]).nonNulls,
    );
  }

  static bool _isWeak(StatusCounts counts, double threshold, int minRefs) =>
      counts.total >= minRefs && counts.issues / counts.total >= threshold;

  static int _byIssuesThenSize(TopicNode a, TopicNode b) {
    final byIssues = b.counts.issues.compareTo(a.counts.issues);
    return byIssues != 0 ? byIssues : b.counts.total.compareTo(a.counts.total);
  }
}
