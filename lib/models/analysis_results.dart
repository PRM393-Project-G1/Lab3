import 'analysis.dart';
import 'reference.dart';
import 'topic.dart';
import 'topic_tree.dart';
import 'weak_topic_rule.dart';

/// A paper with its topics and references, read together.
class AnalysisResults {
  const AnalysisResults({
    this.analysis,
    this.topics = const [],
    this.references = const [],
  });

  /// Null when the paper has never been analyzed.
  final Analysis? analysis;
  final List<Topic> topics;
  final List<Reference> references;

  /// The topic tree under [rule]. Built again whenever the rule changes.
  TopicTree tree(WeakTopicRule rule) =>
      TopicTree.build(topics: topics, references: references, weakRule: rule);
}
