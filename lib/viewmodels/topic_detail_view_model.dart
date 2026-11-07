import '../firebase/analytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic_tree.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class TopicDetailData {
  const TopicDetailData(
    this.node,
    this.references, {
    this.related = const [],
    this.rank,
    this.rankedCount = 0,
  });

  final TopicNode node;

  /// Most severe first.
  final List<Reference> references;

  /// Topics Saffron finds in the same references that are still in the tree,
  /// most similar first.
  final List<TopicNode> related;

  /// 1 for the topic Saffron scores highest in this paper; null when unscored.
  final int? rank;

  /// How many topics have a score, for "#3 of 35".
  final int rankedCount;
}

class TopicDetailViewModel extends BaseViewModel {
  TopicDetailViewModel({
    required this._analyses,
    required this._remoteConfig,
    required this._analytics,
    required this.analysisId,
    required this.topicId,
  }) {
    load();
  }

  final String analysisId;
  final String topicId;
  final AnalysisRepository _analyses;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;

  ViewState<TopicDetailData> _state = const Loading();
  RefStatus? _filter;
  bool _logged = false;

  ViewState<TopicDetailData> get state => _state;

  /// Null means All.
  RefStatus? get filter => _filter;

  List<Reference> get visibleReferences => switch (_state) {
    Data(:final value) =>
      value.references
          .where((ref) => _filter == null || ref.status == _filter)
          .toList(),
    _ => const [],
  };

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      final (topics, references) = await (
        _analyses.getTopics(analysisId),
        _analyses.getReferences(analysisId),
      ).wait;
      final tree = TopicTree.build(
        topics: topics,
        references: references,
        weakThreshold: _remoteConfig.weakTopicThreshold,
        weakMinRefs: _remoteConfig.weakTopicMinRefs,
      );
      final node = tree.byId[topicId];
      if (node == null) {
        _state = const Failure("Couldn't load");
        notifyListeners();
        return;
      }
      final scored = topics.where((t) => t.importance > 0).toList();
      final above = scored
          .where((t) => t.importance > node.topic.importance)
          .length;
      _state = Data(
        TopicDetailData(
          node,
          sortBySeverity(references.where((r) => node.refIds.contains(r.id))),
          related: [
            for (final link in node.topic.related)
              if (tree.byId[link.topicId] case final other?)
                if (other != node) other,
          ],
          rank: node.topic.importance > 0 ? above + 1 : null,
          rankedCount: scored.length,
        ),
      );
      notifyListeners();
      if (!_logged) {
        _logged = true;
        await _analytics.logViewTopic(topicId, node.term, isWeak: node.isWeak);
      }
    } catch (_) {
      _state = const Failure("Couldn't load");
      notifyListeners();
    }
  }

  void setFilter(RefStatus? status) {
    _filter = status;
    notifyListeners();
  }
}
