import 'ref_status.dart';

/// A knowledge area, stored flat at `analyses/{id}/topics/{topicId}`.
class Topic {
  const Topic({
    required this.id,
    required this.term,
    this.parentId,
    this.depth = 0,
    this.refIds = const [],
    this.counts = const StatusCounts(),
  });

  factory Topic.fromMap(String id, Map<String, dynamic> map) => Topic(
    id: id,
    term: map['term'] as String? ?? id,
    parentId: map['parentId'] as String?,
    depth: (map['depth'] as num?)?.toInt() ?? 0,
    refIds: (map['refIds'] as List?)?.cast<String>() ?? const [],
    counts: StatusCounts.fromMap(
      (map['counts'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  final String id;
  final String term;
  final String? parentId;
  final int depth;
  final List<String> refIds;
  final StatusCounts counts;
}
