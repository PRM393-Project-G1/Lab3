import 'ref_status.dart';

/// When a topic is weak: it has enough references, and a large enough share of
/// them are hallucinated or wrong. Warnings do not count.
///
/// Overview, Topics, Topic and the PDF report all ask this one rule, so they
/// can never disagree about which topics are weak.
class WeakTopicRule {
  const WeakTopicRule({required this.threshold, required this.minRefs});

  /// Share of references with issues, from 0 to 1.
  final double threshold;

  /// Smaller topics are never weak.
  final int minRefs;

  /// Whole percent, as shown under the topic tree.
  int get percent => (threshold * 100).round();

  bool isSatisfiedBy(StatusCounts counts) =>
      counts.total >= minRefs && counts.issues / counts.total >= threshold;
}
