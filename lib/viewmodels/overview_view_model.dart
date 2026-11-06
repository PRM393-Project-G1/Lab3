import '../firebase/analytics_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/analysis.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic.dart';
import '../models/topic_tree.dart';
import '../services/analysis_repository.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class OverviewData {
  const OverviewData(this.analysis, this.tree);

  final Analysis analysis;
  final TopicTree tree;

  int get topicCount => tree.byId.length;
  List<TopicNode> get weakTopics => tree.weak;

  /// The most severe status worth an alert. Null when nothing needs attention.
  RefStatus? get alertStatus {
    if (analysis.counts.hallucinated > 0) return RefStatus.hallucinated;
    if (analysis.counts.error > 0) return RefStatus.error;
    return null;
  }
}

class OverviewViewModel extends BaseViewModel {
  OverviewViewModel({
    required this._analyses,
    required this._remoteConfig,
    required this._analytics,
    required this._crashlytics,
    required this.analysisId,
  }) {
    _remoteConfig.addListener(_rebuild);
    load();
  }

  final String analysisId;
  final AnalysisRepository _analyses;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;

  ViewState<OverviewData> _state = const Loading();
  Analysis? _analysis;
  List<Topic> _topics = const [];
  List<Reference> _references = const [];
  bool _logged = false;

  ViewState<OverviewData> get state => _state;
  bool get canExport => _remoteConfig.enableReportExport;

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      final (analysis, topics, references) = await (
        _analyses.getAnalysis(analysisId),
        _analyses.getTopics(analysisId),
        _analyses.getReferences(analysisId),
      ).wait;
      if (analysis == null) {
        _state = const Failure.loadFailed();
        notifyListeners();
        return;
      }
      _analysis = analysis;
      _topics = topics;
      _references = references;
      _rebuild();
      if (!_logged) {
        _logged = true;
        await _analytics.logViewAnalysis(
          analysisId,
          refCount: analysis.totalRefs,
          weakTopicCount: _state.valueOrNull?.weakTopics.length ?? 0,
        );
      }
    } catch (error, stack) {
      _state = const Failure.loadFailed();
      notifyListeners();
      await _crashlytics.recordNonFatal(error, stack, reason: 'load_overview');
    }
  }

  /// Remote Config can change the weak rule while the screen is open.
  void _rebuild() {
    final analysis = _analysis;
    if (analysis == null) {
      notifyListeners();
      return;
    }
    _state = Data(
      OverviewData(
        analysis,
        TopicTree.build(
          topics: _topics,
          references: _references,
          weakThreshold: _remoteConfig.weakTopicThreshold,
          weakMinRefs: _remoteConfig.weakTopicMinRefs,
        ),
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _remoteConfig.removeListener(_rebuild);
    super.dispose();
  }
}
