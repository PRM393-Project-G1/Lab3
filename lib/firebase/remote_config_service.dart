import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../models/weak_topic_rule.dart';

/// Parameter names in the Firebase Console. Keep in sync with
/// `firebase/remote-config-defaults.json`.
abstract final class RemoteConfigKeys {
  static const weakTopicThreshold = 'weak_topic_threshold';
  static const weakTopicMinRefs = 'weak_topic_min_refs';
  static const maxRecentChecks = 'max_recent_checks';
  static const enableReportExport = 'enable_report_export';
  static const enableCloudUpload = 'enable_cloud_upload';
  static const geminiModel = 'gemini_model';
}

/// Values changed from the Firebase Console without a new build.
abstract class RemoteConfigService extends ChangeNotifier {
  double get weakTopicThreshold;
  int get weakTopicMinRefs;
  int get maxRecentChecks;
  bool get enableReportExport;

  /// Uploads the report to Cloudinary when on. Off by default: the backend
  /// needs its CLOUDINARY_* settings first.
  bool get enableCloudUpload;

  /// Gemini model that names the relations on the knowledge graph.
  String get geminiModel;
}

/// Derived from the parameters, so every implementation and test double agrees.
extension RemoteConfigValues on RemoteConfigService {
  /// The weak-topic rule as currently set in the Firebase Console.
  WeakTopicRule get weakTopicRule =>
      WeakTopicRule(threshold: weakTopicThreshold, minRefs: weakTopicMinRefs);

  /// Each parameter with its current value, in Console order.
  List<(String, Object)> get parameters => [
    (RemoteConfigKeys.weakTopicThreshold, weakTopicThreshold),
    (RemoteConfigKeys.weakTopicMinRefs, weakTopicMinRefs),
    (RemoteConfigKeys.maxRecentChecks, maxRecentChecks),
    (RemoteConfigKeys.enableReportExport, enableReportExport),
    (RemoteConfigKeys.enableCloudUpload, enableCloudUpload),
    (RemoteConfigKeys.geminiModel, geminiModel),
  ];
}

class FirebaseRemoteConfigService extends RemoteConfigService {
  FirebaseRemoteConfigService({FirebaseRemoteConfig? config})
    : _config = config ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _config;
  StreamSubscription<RemoteConfigUpdate>? _updates;

  /// Keep in sync with `firebase/remote-config-defaults.json`.
  static const defaults = <String, dynamic>{
    RemoteConfigKeys.weakTopicThreshold: 0.5,
    RemoteConfigKeys.weakTopicMinRefs: 3,
    RemoteConfigKeys.maxRecentChecks: 10,
    RemoteConfigKeys.enableReportExport: true,
    RemoteConfigKeys.enableCloudUpload: false,
    RemoteConfigKeys.geminiModel: 'gemini-3.5-flash-lite',
  };

  Future<void> init() async {
    await _config.setDefaults(defaults);
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    try {
      await _config.fetchAndActivate();
    } catch (_) {
      // Defaults and the last activated values still apply when offline.
    }
    _updates = _config.onConfigUpdated.listen((_) async {
      await _config.activate();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }

  @override
  double get weakTopicThreshold =>
      _config.getDouble(RemoteConfigKeys.weakTopicThreshold);

  @override
  int get weakTopicMinRefs => _config.getInt(RemoteConfigKeys.weakTopicMinRefs);

  @override
  int get maxRecentChecks => _config.getInt(RemoteConfigKeys.maxRecentChecks);

  @override
  bool get enableReportExport =>
      _config.getBool(RemoteConfigKeys.enableReportExport);

  @override
  bool get enableCloudUpload =>
      _config.getBool(RemoteConfigKeys.enableCloudUpload);

  @override
  String get geminiModel => _config.getString(RemoteConfigKeys.geminiModel);
}
