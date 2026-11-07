import 'ref_status.dart';

/// A knowledge area, stored flat at `analyses/{id}/topics/{topicId}`.
///
/// [importance], [occurrences], [related] and [authors] come from Saffron's
/// other files. Analyses made before they were saved have none of them.
class Topic {
  const Topic({
    required this.id,
    required this.term,
    this.parentId,
    this.depth = 0,
    this.refIds = const [],
    this.counts = const StatusCounts(),
    this.importance = 0,
    this.occurrences = 0,
    this.related = const [],
    this.authors = const [],
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
    importance: (map['importance'] as num?)?.toDouble() ?? 0,
    occurrences: (map['occurrences'] as num?)?.toInt() ?? 0,
    related: _listOf(map['related'], RelatedTopic._fromMap),
    authors: _listOf(map['authors'], TopicAuthor._fromMap),
  );

  final String id;
  final String term;
  final String? parentId;
  final int depth;
  final List<String> refIds;
  final StatusCounts counts;

  /// Saffron's score for the term across the cited works. Only the order means
  /// something: the scale changes from paper to paper.
  final double importance;

  /// How many times the cited works mention the term.
  final int occurrences;

  /// Topics that appear in the same references, most similar first.
  final List<RelatedTopic> related;

  /// Cited authors who write most about this topic, strongest first.
  final List<TopicAuthor> authors;

  /// "31 mentions", or null when Saffron gave no count.
  String? get mentions => switch (occurrences) {
    <= 0 => null,
    1 => '1 mention',
    _ => '$occurrences mentions',
  };
}

class RelatedTopic {
  const RelatedTopic({
    required this.topicId,
    required this.term,
    this.similarity = 0,
  });

  static RelatedTopic? _fromMap(Map<String, dynamic> map) {
    final topicId = map['topicId'];
    if (topicId is! String || topicId.isEmpty) return null;
    return RelatedTopic(
      topicId: topicId,
      term: map['term'] as String? ?? topicId,
      similarity: (map['similarity'] as num?)?.toDouble() ?? 0,
    );
  }

  final String topicId;
  final String term;
  final double similarity;
}

class TopicAuthor {
  const TopicAuthor({required this.name, this.score = 0});

  static TopicAuthor? _fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty) return null;
    return TopicAuthor(
      name: name,
      score: (map['score'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final double score;
}

/// Skips entries that are not maps or lack their key fields.
List<T> _listOf<T>(Object? value, T? Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) ?parse(item.cast<String, dynamic>()),
  ];
}
