import 'dart:async';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/messaging_service.dart';
import '../firebase/remote_config_service.dart';
import '../models/app_user.dart';
import '../models/library_entry.dart';
import '../services/library_feed.dart';
import '../services/report_files.dart';
import '../services/server_settings.dart';
import 'base_view_model.dart';

class ProfileViewModel extends BaseViewModel {
  ProfileViewModel({
    required AuthService auth,
    required this._settings,
    required this._remoteConfig,
    required this._analytics,
    required this._crashlytics,
    required this._files,
    required this._messaging,
    required LibraryFeed feed,
  }) : _auth = auth {
    _settings.addListener(notifyListeners);
    _remoteConfig.addListener(notifyListeners);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      _feedSub = feed.watch(uid).listen((entries) {
        _entries = entries;
        notifyListeners();
      }, onError: (Object _) {});
    }
  }

  final AuthService _auth;
  final ServerSettings _settings;
  final RemoteConfigService _remoteConfig;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;
  final ReportFiles _files;
  final MessagingService _messaging;

  StreamSubscription<List<LibraryEntry>>? _feedSub;
  List<LibraryEntry> _entries = const [];

  AppUser? get user => _auth.currentUser;
  bool get aiCheck => _settings.aiCheck;
  String get serverUrl => _settings.serverUrl ?? '';

  /// The newest finished analysis, used by the Export report demo.
  String? get latestDoneId {
    for (final entry in _entries) {
      if (entry.analysis?.isDone ?? false) return entry.arxivId;
    }
    return null;
  }

  /// Key and current value of each Remote Config parameter.
  List<(String, String)> get remoteConfigRows => [
    ('weak_topic_threshold', '${_remoteConfig.weakTopicThreshold}'),
    ('weak_topic_min_refs', '${_remoteConfig.weakTopicMinRefs}'),
    ('max_recent_checks', '${_remoteConfig.maxRecentChecks}'),
    ('enable_report_export', '${_remoteConfig.enableReportExport}'),
    ('enable_cloud_upload', '${_remoteConfig.enableCloudUpload}'),
  ];

  Future<void> setAiCheck(bool value) => _settings.setAiCheck(value);

  Future<void> logError() => _crashlytics.recordNonFatal(
    StateError('Test non-fatal error'),
    StackTrace.current,
    reason: 'firebase_demo',
  );

  void testCrash() => _crashlytics.testCrash();

  Future<void> signOut() async {
    await _analytics.logLogout();
    try {
      await _messaging.deleteToken();
    } catch (error, stack) {
      // With no network, signing out still has to work.
      await _crashlytics.recordNonFatal(error, stack, reason: 'delete_token');
    }
    await _auth.signOut();
    await _settings.clear();
    await _files.clear();
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _settings.removeListener(notifyListeners);
    _remoteConfig.removeListener(notifyListeners);
    super.dispose();
  }
}
