import '../firebase/analytics_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/analysis.dart';
import '../models/analysis_results.dart';
import '../models/ref_status.dart';
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
  AnalysisResults? _results;
  bool _logged = false;

  ViewState<OverviewData> get state => _state;
  bool get canExport => _remoteConfig.enableReportExport;

  /// Why there is nothing to show when an administrator hid or deleted the
  /// results. Null for ordinary load errors, which are worth a retry.
  String? get unavailableMessage => _unavailableMessage;
  String? _unavailableMessage;

  static const deletedMessage =
      'An administrator may have removed it. Analyze the paper again for fresh results.';

  static String hiddenMessage(String? reason) =>
      reason == null || reason.isEmpty
      ? 'An administrator removed these results.'
      : 'An administrator removed these results: $reason';

  Future<void> load() async {
    _state = const Loading();
    _unavailableMessage = null;
    notifyListeners();
    try {
      final results = await _analyses.getResults(analysisId);
      final analysis = results.analysis;
      if (analysis == null || analysis.hidden) {
        _unavailableMessage = analysis == null
            ? deletedMessage
            : hiddenMessage(analysis.hiddenReason);
        _state = const Failure('Results unavailable');
        notifyListeners();
        return;
      }
      _results = results;
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
    final results = _results;
    final analysis = results?.analysis;
    if (results == null || analysis == null) {
      notifyListeners();
      return;
    }
    _state = Data(
      OverviewData(analysis, results.tree(_remoteConfig.weakTopicRule)),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _remoteConfig.removeListener(_rebuild);
    super.dispose();
  }
}
