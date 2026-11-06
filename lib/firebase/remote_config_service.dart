import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Values changed from the Firebase Console without a new build.
abstract class RemoteConfigService extends ChangeNotifier {
  double get weakTopicThreshold;
  int get weakTopicMinRefs;
  int get maxRecentChecks;
  bool get enableReportExport;

  /// Uploads the report to Cloudinary when on. Off by default: the backend
  /// needs its CLOUDINARY_* settings first.
  bool get enableCloudUpload;
}

class FirebaseRemoteConfigService extends RemoteConfigService {
  FirebaseRemoteConfigService({FirebaseRemoteConfig? config})
    : _config = config ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _config;
  StreamSubscription<RemoteConfigUpdate>? _updates;

  /// Keep in sync with `firebase/remote-config-defaults.json`.
  static const defaults = <String, dynamic>{
    'weak_topic_threshold': 0.5,
    'weak_topic_min_refs': 3,
    'max_recent_checks': 10,
    'enable_report_export': true,
    'enable_cloud_upload': false,
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
  double get weakTopicThreshold => _config.getDouble('weak_topic_threshold');

  @override
  int get weakTopicMinRefs => _config.getInt('weak_topic_min_refs');

  @override
  int get maxRecentChecks => _config.getInt('max_recent_checks');

  @override
  bool get enableReportExport => _config.getBool('enable_report_export');

  @override
  bool get enableCloudUpload => _config.getBool('enable_cloud_upload');
}
