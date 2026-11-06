import 'dart:typed_data';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/remote_config_service.dart';
import '../firebase/storage_service.dart';
import '../models/analysis.dart';
import '../models/analysis_results.dart';
import '../models/reference.dart';
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
    _progress = 0;
    _enter(ExportPhase.creating);
    try {
      final uid = _auth.currentUser?.uid;
      final results = await _analyses.getResults(analysisId);
      final analysis = results.analysis;
      if (uid == null || analysis == null) {
        throw StateError('Nothing to export');
      }
      final bytes = await _buildPdf(analysis, results);
      _sizeKb = (bytes.length / 1024).ceil();
      _path = await _files.save(uid: uid, fileName: fileName, bytes: bytes);
      if (_remoteConfig.enableCloudUpload) {
        _url = await _upload(uid, bytes);
        _enter(ExportPhase.uploaded);
      } else {
        _enter(ExportPhase.saved);
      }
      await _analytics.logExportReport(analysisId, fileSizeKb: _sizeKb);
    } catch (error, stack) {
      _enter(ExportPhase.failed);
      await _crashlytics.recordNonFatal(error, stack, reason: 'export_report');
    }
  }

  /// Weak topics, then every reference with a problem, most severe first.
  Future<Uint8List> _buildPdf(Analysis analysis, AnalysisResults results) =>
      _report.buildReport(
        analysis: analysis,
        weakTopics: results.tree(_remoteConfig.weakTopicRule).weak,
        flagged: sortBySeverity(
          results.references.where((r) => r.status.isFlagged),
        ),
      );

  /// Uploads to Cloud Storage, records the metadata and returns the link.
  Future<String> _upload(String uid, Uint8List bytes) async {
    _enter(ExportPhase.uploading);
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
    return uploaded.url;
  }

  void _enter(ExportPhase phase) {
    _phase = phase;
    notifyListeners();
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
