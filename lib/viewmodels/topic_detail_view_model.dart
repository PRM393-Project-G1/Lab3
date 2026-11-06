import '../firebase/analytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic_tree.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class TopicDetailData {
  const TopicDetailData(this.node, this.references);

  final TopicNode node;

  /// Most severe first.
  final List<Reference> references;
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

  List<Reference> get visibleReferences => [
    for (final ref in _state.valueOrNull?.references ?? const <Reference>[])
      if (_filter == null || ref.status == _filter) ref,
  ];

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
        weakRule: _remoteConfig.weakTopicRule,
      );
      final node = tree.byId[topicId];
      if (node == null) {
        _state = const Failure.loadFailed();
        notifyListeners();
        return;
      }
      _state = Data(
        TopicDetailData(
          node,
          sortBySeverity(references.where((r) => node.refIds.contains(r.id))),
        ),
      );
      notifyListeners();
      if (!_logged) {
        _logged = true;
        await _analytics.logViewTopic(topicId, node.term, isWeak: node.isWeak);
      }
    } catch (_) {
      _state = const Failure.loadFailed();
      notifyListeners();
    }
  }

  void setFilter(RefStatus? status) {
    _filter = status;
    notifyListeners();
  }
}
