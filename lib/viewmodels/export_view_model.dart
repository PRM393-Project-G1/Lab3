import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/remote_config_service.dart';
import '../firebase/storage_service.dart';
import '../models/reference.dart';
import '../models/topic_tree.dart';
import '../services/analysis_repository.dart';
import '../services/device_actions.dart';
import '../services/report_files.dart';
import '../services/report_service.dart';
import 'base_view_model.dart';

enum ExportPhase { creating, uploading, uploaded, saved, failed }

/// Creates the PDF and saves it on the device. When `enable_cloud_upload` is on,
/// also uploads it to `reports/{uid}/…` and records its metadata.
class ExportViewModel extends BaseViewModel {
  ExportViewModel({
    required this._report,
    required this._files,
    required this._storage,
    required this._firestore,
    required this._analyses,
    required this._remoteConfig,
    required this._auth,
    required this._analytics,
    required this._crashlytics,
    required this._device,
    required this.analysisId,
  });

  final String analysisId;
  final ReportService _report;
  final ReportFiles _files;
  final StorageService _storage;
  final FirestoreService _firestore;
  final AnalysisRepository _analyses;
  final RemoteConfigService _remoteConfig;
  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;
  final DeviceActions _device;

  ExportPhase _phase = ExportPhase.creating;
  double _progress = 0;
  String? _url;
  String? _path;
  int _sizeKb = 0;

  ExportPhase get phase => _phase;
  double get progress => _progress;
  String get fileName => 'realtron_$analysisId.pdf';
  String get fileLabel => '$fileName · $_sizeKb KB';

  Future<void> start() async {
    _phase = ExportPhase.creating;
    _progress = 0;
    notifyListeners();
    try {
      final uid = _auth.currentUser?.uid;
      final (analysis, topics, references) = await (
        _analyses.getAnalysis(analysisId),
        _analyses.getTopics(analysisId),
        _analyses.getReferences(analysisId),
      ).wait;
      if (uid == null || analysis == null) {
        throw StateError('Nothing to export');
      }
      final tree = TopicTree.build(
        topics: topics,
        references: references,
        weakRule: _remoteConfig.weakTopicRule,
      );
      final bytes = await _report.buildReport(
        analysis: analysis,
        weakTopics: tree.weak,
        flagged: sortBySeverity(references.where((r) => r.status.isFlagged)),
      );
      _sizeKb = (bytes.length / 1024).ceil();
      _path = await _files.save(uid: uid, fileName: fileName, bytes: bytes);
      if (!_remoteConfig.enableCloudUpload) {
        _phase = ExportPhase.saved;
        notifyListeners();
        await _analytics.logExportReport(analysisId, fileSizeKb: _sizeKb);
        return;
      }
      _phase = ExportPhase.uploading;
      notifyListeners();
      final uploaded = await _storage.uploadReport(
        uid: uid,
        fileName: fileName,
        bytes: bytes,
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      await _firestore.addReport(
        uid: uid,
        analysisId: analysisId,
        storagePath: uploaded.path,
        downloadUrl: uploaded.url,
        sizeKb: _sizeKb,
      );
      _url = uploaded.url;
      _phase = ExportPhase.uploaded;
      notifyListeners();
      await _analytics.logExportReport(analysisId, fileSizeKb: _sizeKb);
    } catch (error, stack) {
      _phase = ExportPhase.failed;
      notifyListeners();
      await _crashlytics.recordNonFatal(error, stack, reason: 'export_report');
    }
  }

  Future<void> copyLink() async {
    if (_url != null) await _device.copy(_url!);
  }

  Future<void> share() async {
    if (_url != null) {
      await _device.share(_url!);
    } else if (_path != null) {
      await _device.sharePdf(_path!);
    }
  }

  /// Returns false when no installed app can open the PDF.
  Future<bool> open() async => _path != null && await _device.openPdf(_path!);
}
