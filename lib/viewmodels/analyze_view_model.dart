import 'dart:async';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/library_entry.dart';
import '../services/analysis_repository.dart';
import '../services/api_client.dart';
import '../services/device_actions.dart';
import '../services/library_feed.dart';
import '../services/library_repository.dart';
import '../services/server_settings.dart';
import '../utils/arxiv_id.dart';
import 'base_view_model.dart';
import 'view_state.dart';

/// Where to go after a successful submit.
class AnalyzeTarget {
  const AnalyzeTarget(this.arxivId, {required this.ready});

  final String arxivId;

  /// True when a finished result already exists.
  final bool ready;
}

enum AnalyzeProblem { unreachable, failed }

class AnalyzeViewModel extends BaseViewModel {
  AnalyzeViewModel({
    required this._api,
    required this._analyses,
    required this._library,
    required this._feed,
    required this._auth,
    required this._settings,
    required this._remoteConfig,
    required this._analytics,
    required this._crashlytics,
    required this._device,
    String? sharedText,
  }) {
    _settings.addListener(notifyListeners);
    _remoteConfig.addListener(notifyListeners);
    if (sharedText != null) setInput(sharedText);
    loadRecent();
  }

  static const example = '1706.03762';

  final ApiClient _api;
  final AnalysisRepository _analyses;
  final LibraryRepository _library;
  final LibraryFeed _feed;
  final AuthService _auth;
  final ServerSettings _settings;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;
  final DeviceActions _device;

  StreamSubscription<List<LibraryEntry>>? _recentSub;
  ViewState<List<LibraryEntry>> _recent = const Loading();
  String _input = '';
  String? _arxivId;
  bool _submitting = false;
  AnalyzeProblem? _problem;

  String get input => _input;
  bool get showInvalid => _input.trim().isNotEmpty && _arxivId == null;
  bool get canSubmit => _arxivId != null && !_submitting;
  bool get submitting => _submitting;
  AnalyzeProblem? get problem => _problem;
  bool get aiCheck => _settings.aiCheck;

  ViewState<List<LibraryEntry>> get recent => switch (_recent) {
    Data(:final value) => Data(
      value.take(_remoteConfig.maxRecentChecks).toList(),
    ),
    final other => other,
  };

  void setInput(String value) {
    _input = value;
    _arxivId = parseArxivId(value);
    _problem = null;
    notifyListeners();
  }

  Future<String?> paste() async {
    final text = await _device.paste();
    if (text != null) setInput(text.trim());
    return text?.trim();
  }

  Future<void> setAiCheck(bool value) => _settings.setAiCheck(value);

  void loadRecent() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _recentSub?.cancel();
    _recent = const Loading();
    _recentSub = _feed
        .watch(uid)
        .listen(
          (entries) {
            _recent = listState(entries);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            _recent = const Failure.loadFailed();
            _crashlytics.recordNonFatal(error, stack, reason: 'load_recent');
            notifyListeners();
          },
        );
  }

  /// Reuses a finished result when there is one; otherwise asks the backend.
  /// Returns null when a problem is now set.
  Future<AnalyzeTarget?> submit() async {
    final id = _arxivId;
    final uid = _auth.currentUser?.uid;
    if (id == null || uid == null || _submitting) return null;
    _submitting = true;
    _problem = null;
    notifyListeners();
    try {
      final existing = await _analyses.getAnalysis(id);
      final cached = existing?.isDone ?? false;
      await _analytics.logSearch(id, cacheHit: cached);
      if (!cached && !(existing?.isRunning ?? false)) {
        await _api.startAnalysis(id, aiAssisted: aiCheck);
      }
      // A Firestore write only finishes once the server answers, so waiting
      // for it would keep a cached result from opening while offline.
      unawaited(_touch(uid, id));
      return AnalyzeTarget(id, ready: cached);
    } on OfflineException {
      _problem = AnalyzeProblem.unreachable;
      return null;
    } on ApiException catch (error) {
      _problem = error.failure == ApiFailure.rejected
          ? AnalyzeProblem.failed
          : AnalyzeProblem.unreachable;
      return null;
    } catch (error, stack) {
      await _crashlytics.recordNonFatal(error, stack, reason: 'analyze_submit');
      _problem = AnalyzeProblem.failed;
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> _touch(String uid, String id) async {
    try {
      await _library.addOrTouch(uid, id);
    } catch (error, stack) {
      await _crashlytics.recordNonFatal(error, stack, reason: 'touch_library');
    }
  }

  @override
  void dispose() {
    _recentSub?.cancel();
    _settings.removeListener(notifyListeners);
    _remoteConfig.removeListener(notifyListeners);
    super.dispose();
  }
}
