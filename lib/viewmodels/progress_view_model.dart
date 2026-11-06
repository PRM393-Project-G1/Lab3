import 'dart:async';

import '../models/analysis.dart';
import '../services/analysis_repository.dart';
import '../services/api_client.dart';
import '../services/server_settings.dart';
import 'base_view_model.dart';
import 'view_state.dart';

enum ProgressStepState { pending, active, done, failed }

class ProgressStep {
  const ProgressStep(this.label, this.state);

  final String label;
  final ProgressStepState state;
}

class ProgressViewModel extends BaseViewModel {
  ProgressViewModel({
    required this._analyses,
    required this._api,
    required this._settings,
    required this.analysisId,
    Duration missingAfter = const Duration(seconds: 30),
  }) {
    // The document can appear just after the backend accepts the job, but
    // not this late. It still recovers if the document does arrive.
    _missing = Timer(missingAfter, () {
      if (_state is! Loading) return;
      _state = const Failure.loadFailed();
      notifyListeners();
    });
    _sub = _analyses
        .watchAnalysis(analysisId)
        .listen(
          (analysis) {
            if (analysis != null) {
              _missing.cancel();
              _state = Data(analysis);
            }
            notifyListeners();
          },
          onError: (Object _) {
            _state = const Failure.loadFailed();
            notifyListeners();
          },
        );
  }

  static const _labels = {
    AnalysisStage.references: 'References',
    AnalysisStage.verify: 'Verify',
    AnalysisStage.fabrication: 'Fabrication check',
    AnalysisStage.fullText: 'Full text',
    AnalysisStage.topics: 'Topics',
  };

  final String analysisId;
  final AnalysisRepository _analyses;
  final ApiClient _api;
  final ServerSettings _settings;

  late final StreamSubscription<Analysis?> _sub;
  late final Timer _missing;
  ViewState<Analysis> _state = const Loading();
  bool _busy = false;
  bool _commandFailed = false;

  ViewState<Analysis> get state => _state;
  Analysis? get analysis => _state.valueOrNull;

  bool get busy => _busy;

  /// A Stop or Retry command could not reach the backend.
  bool get commandFailed => _commandFailed;

  bool get isDone => analysis?.isDone ?? false;

  bool get isFailed => analysis?.isStopped ?? false;

  bool get isOffline => analysis?.fromCache ?? false;

  double get fraction => isDone ? 1 : (analysis?.progress.percent ?? 0) / 100;

  String get refsLabel {
    final total = analysis?.totalRefs ?? 0;
    final done = analysis?.progress.processedRefs ?? 0;
    return total > 0
        ? '$done/$total refs'
        : '${analysis?.progress.percent ?? 0}%';
  }

  String get failureReason =>
      analysis?.error ??
      (analysis?.status == AnalysisStatus.cancelled
          ? 'Stopped.'
          : 'Something went wrong.');

  List<ProgressStep> get steps {
    final current = analysis?.progress.stage ?? AnalysisStage.references;
    return [
      for (final stage in AnalysisStage.values)
        ProgressStep(_labels[stage]!, _stepState(stage, current)),
    ];
  }

  ProgressStepState _stepState(AnalysisStage stage, AnalysisStage current) {
    if (isDone || stage.index < current.index) return ProgressStepState.done;
    if (stage.index > current.index) return ProgressStepState.pending;
    return isFailed ? ProgressStepState.failed : ProgressStepState.active;
  }

  /// Returns true when the backend accepted the stop.
  Future<bool> stop() => _command(() => _api.cancelAnalysis(analysisId));

  Future<bool> retry() => _command(
    () => _api.startAnalysis(analysisId, aiAssisted: _settings.aiCheck),
  );

  Future<bool> _command(Future<void> Function() call) async {
    _busy = true;
    _commandFailed = false;
    notifyListeners();
    try {
      await call();
      return true;
    } on ApiException {
      _commandFailed = true;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _missing.cancel();
    _sub.cancel();
    super.dispose();
  }
}
