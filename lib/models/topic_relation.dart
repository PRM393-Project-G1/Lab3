/// A named relation between two topics, labelled by Gemini.
enum RelationKind {
  /// [TopicRelation.from] is a kind or subfield of [TopicRelation.to].
  isA('is_a'),

  /// [TopicRelation.from] is a component of [TopicRelation.to].
  partOf('part_of'),

  /// Both name the same concept.
  sameAs('same_as');

  const RelationKind(this.key);

  /// The value in Gemini's JSON answer.
  final String key;

  static RelationKind? fromKey(Object? key) {
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

/// Holds topic terms when it comes from Gemini, and topic ids once matched to
/// the paper's topics.
class TopicRelation {
  const TopicRelation(this.from, this.to, this.kind);

  final String from;
  final String to;
  final RelationKind kind;

  @override
  bool operator ==(Object other) =>
      other is TopicRelation &&
      other.from == from &&
      other.to == to &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(from, to, kind);

  @override
  String toString() => '$from ${kind.key} $to';
}
