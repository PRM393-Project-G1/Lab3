import '../firebase/analytics_service.dart';
import '../models/ref_status.dart';
import '../models/reference.dart';
import '../models/topic.dart';
import '../services/analysis_repository.dart';
import '../services/device_actions.dart';
import 'base_view_model.dart';
import 'view_state.dart';

class ReferenceDetailViewModel extends BaseViewModel {
  ReferenceDetailViewModel({
    required this._analyses,
    required this._device,
    required this._analytics,
    required this.analysisId,
    required this.referenceId,
  }) {
    load();
  }

  final String analysisId;
  final String referenceId;
  final AnalysisRepository _analyses;
  final DeviceActions _device;
  final AnalyticsService _analytics;

  ViewState<Reference> _state = const Loading();
  List<Topic> _topics = const [];
  bool _logged = false;
  bool _promptShown = false;

  ViewState<Reference> get state => _state;

  /// Topics this reference belongs to.
  List<Topic> get topics => _topics;

  /// The fabrication dialog opens by itself once per visit.
  bool takeFabricationPrompt() {
    final ref = _state.valueOrNull;
    if (_promptShown || ref?.status != RefStatus.hallucinated) return false;
    _promptShown = true;
    return true;
  }

  Future<void> load() async {
    _state = const Loading();
    notifyListeners();
    try {
      final (ref, topics) = await (
        _analyses.getReference(analysisId, referenceId),
        _analyses.getTopics(analysisId),
      ).wait;
      if (ref == null) {
        _state = const Failure.loadFailed();
        notifyListeners();
        return;
      }
      _topics = topics.where((t) => ref.topicIds.contains(t.id)).toList();
      _state = Data(ref);
      notifyListeners();
      if (!_logged) {
        _logged = true;
        await _analytics.logViewReference(referenceId, ref.status.name);
      }
    } catch (_) {
      _state = const Failure.loadFailed();
      notifyListeners();
    }
  }

  Future<void> copyFix(Reference ref) => _device.copy(ref.fixText);

  Future<void> openUrl(String url) => _device.openUrl(url);

  Future<void> searchWeb(Reference ref) => _device.searchWeb(ref.title);
}
