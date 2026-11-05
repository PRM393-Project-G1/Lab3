import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:realtron/firebase/analytics_service.dart';
import 'package:realtron/firebase/auth_service.dart';
import 'package:realtron/firebase/crashlytics_service.dart';
import 'package:realtron/firebase/firestore_service.dart';
import 'package:realtron/firebase/messaging_service.dart';
import 'package:realtron/firebase/remote_config_service.dart';
import 'package:realtron/firebase/storage_service.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/models/app_notification.dart';
import 'package:realtron/models/app_user.dart';
import 'package:realtron/models/library_entry.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/reference.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/models/topic_tree.dart';
import 'package:realtron/services/analysis_repository.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/device_actions.dart';
import 'package:realtron/services/library_repository.dart';
import 'package:realtron/services/report_files.dart';
import 'package:realtron/services/report_service.dart';

const testUser = AppUser(uid: 'u1', displayName: 'Linh');

class FakeAuth implements AuthService {
  FakeAuth({this.currentUser = testUser});

  @override
  AppUser? currentUser;

  SignInResult result = SignInResult.success;
  bool signedOut = false;
  Object? tokenError;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  @override
  Future<SignInResult> signInWithGoogle() async {
    if (result == SignInResult.success) {
      currentUser = testUser;
      _changes.add(testUser);
    }
    return result;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    currentUser = null;
  }

  /// Sends a sign-in or sign-out, as Firebase Auth would.
  void change(AppUser? user) {
    currentUser = user;
    _changes.add(user);
  }

  @override
  Future<String?> idToken() async {
    if (tokenError != null) throw tokenError!;
    return 'token';
  }
}

class FakeMessaging implements MessagingService {
  int starts = 0;
  bool deleted = false;
  bool failDelete = false;

  @override
  Stream<PushMessage> get foreground => const Stream.empty();
  @override
  Stream<PushMessage> get opened => const Stream.empty();

  @override
  Future<void> start(Future<void> Function(String token) onToken) async {
    starts++;
    await onToken('t1');
  }

  @override
  Future<void> deleteToken() async {
    if (failDelete) throw StateError('offline');
    deleted = true;
  }
}

class FakeAnalytics implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> setUser(String? uid) async {}
  @override
  Future<void> logLogin() async => events.add('login');
  @override
  Future<void> logLogout() async => events.add('logout');
  @override
  Future<void> logSearch(String arxivId, {required bool cacheHit}) async =>
      events.add('search:$cacheHit');
  @override
  Future<void> logViewAnalysis(
    String id, {
    required int refCount,
    required int weakTopicCount,
  }) async => events.add('view_analysis:$refCount:$weakTopicCount');
  @override
  Future<void> logViewTopic(
    String topicId,
    String name, {
    required bool isWeak,
  }) async => events.add('view_topic:$isWeak');
  @override
  Future<void> logViewReference(String refId, String status) async =>
      events.add('view_reference:$status');
  @override
  Future<void> logFilterWeakTopics(String id) async =>
      events.add('filter_weak_topics');
  @override
  Future<void> logExportReport(String id, {required int fileSizeKb}) async =>
      events.add('export_report');
  @override
  Future<void> logNotificationOpen(String type) async =>
      events.add('notification_open:$type');
}

class FakeCrashlytics implements CrashlyticsService {
  final recorded = <String?>[];
  final keys = <String, Object>{};
  bool crashed = false;

  @override
  Future<void> setUser(String uid) async {}
  @override
  Future<void> setKey(String key, Object value) async => keys[key] = value;
  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async => recorded.add(reason);
  @override
  void testCrash() => crashed = true;
}

class FakeRemoteConfig extends ChangeNotifier implements RemoteConfigService {
  @override
  double weakTopicThreshold = 0.5;
  @override
  int weakTopicMinRefs = 3;
  @override
  int maxRecentChecks = 10;
  @override
  bool enableReportExport = true;
  @override
  bool enableCloudUpload = false;

  void change(VoidCallback update) {
    update();
    notifyListeners();
  }
}

class FakeApi implements ApiClient {
  ApiFailure? failure;
  Object? healthError;
  int latency = 84;
  final started = <String>[];
  final cancelled = <String>[];

  void _maybeFail() {
    if (failure != null) throw ApiException(failure!);
  }

  @override
  Future<int> health(String baseUrl) async {
    if (healthError != null) throw healthError!;
    _maybeFail();
    return latency;
  }

  @override
  Future<void> startAnalysis(String arxivId, {required bool aiAssisted}) async {
    _maybeFail();
    started.add(arxivId);
  }

  @override
  Future<void> cancelAnalysis(String arxivId) async {
    _maybeFail();
    cancelled.add(arxivId);
  }
}

class FakeAnalyses implements AnalysisRepository {
  final analyses = <String, Analysis>{};
  final topics = <String, List<Topic>>{};
  final references = <String, List<Reference>>{};
  final _watchers = <String, StreamController<Analysis?>>{};
  bool fail = false;
  Object? getError;

  void _maybeFail() {
    if (fail) throw StateError('offline');
  }

  /// Sends a new value to whoever is watching this analysis.
  void push(Analysis analysis) {
    analyses[analysis.id] = analysis;
    _watchers[analysis.id]?.add(analysis);
  }

  void pushError(String id) => _watchers[id]?.addError(StateError('denied'));

  @override
  Future<Analysis?> getAnalysis(String id) async {
    if (getError != null) throw getError!;
    _maybeFail();
    return analyses[id];
  }

  @override
  Stream<Analysis?> watchAnalysis(String id) {
    final controller = _watchers.putIfAbsent(
      id,
      () => StreamController<Analysis?>.broadcast(),
    );
    scheduleMicrotask(() => controller.add(analyses[id]));
    return controller.stream;
  }

  @override
  Future<List<Topic>> getTopics(String id) async {
    _maybeFail();
    return topics[id] ?? const [];
  }

  @override
  Future<List<Reference>> getReferences(String id) async {
    _maybeFail();
    return references[id] ?? const [];
  }

  @override
  Future<Reference?> getReference(String id, String refId) async {
    _maybeFail();
    for (final ref in references[id] ?? const <Reference>[]) {
      if (ref.id == refId) return ref;
    }
    return null;
  }
}

class FakeLibrary implements LibraryRepository {
  final _entries = StreamController<List<LibraryEntry>>.broadcast();
  final touched = <String>[];
  final removed = <String>[];
  final renamed = <String, String>{};
  List<LibraryEntry> entries = const [];
  bool failWrites = false;
  bool hangTouch = false;

  void emit(List<LibraryEntry> value) {
    entries = value;
    _entries.add(value);
  }

  void emitError() => _entries.addError(StateError('offline'));

  @override
  Stream<List<LibraryEntry>> watchLibrary(String uid) {
    scheduleMicrotask(() => _entries.add(entries));
    return _entries.stream;
  }

  @override
  Future<void> addOrTouch(String uid, String arxivId) async {
    if (failWrites) throw StateError('offline');
    touched.add(arxivId);
    if (hangTouch) await Completer<void>().future;
  }

  @override
  Future<void> rename(String uid, String arxivId, String title) async {
    if (failWrites) throw StateError('offline');
    renamed[arxivId] = title;
  }

  @override
  Future<void> remove(String uid, String arxivId) async {
    if (failWrites) throw StateError('offline');
    removed.add(arxivId);
  }
}

class FakeDevice implements DeviceActions {
  String? clipboard;
  final opened = <String>[];
  final searched = <String>[];
  final shared = <String>[];
  final openedPdfs = <String>[];
  final sharedPdfs = <String>[];
  bool canOpenPdf = true;

  @override
  Future<void> copy(String text) async => clipboard = text;
  @override
  Future<String?> paste() async => clipboard;
  @override
  Future<void> openUrl(String url) async => opened.add(url);
  @override
  Future<void> searchWeb(String query) async => searched.add(query);
  @override
  Future<void> share(String text) async => shared.add(text);
  @override
  Future<bool> openPdf(String path) async {
    openedPdfs.add(path);
    return canOpenPdf;
  }

  @override
  Future<void> sharePdf(String path) async => sharedPdfs.add(path);
}

class FakeReportFiles implements ReportFiles {
  final saved = <String>[];
  bool fail = false;
  bool cleared = false;

  @override
  Future<String> save({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (fail) throw StateError('disk full');
    final path = '/files/$uid/$fileName';
    saved.add(path);
    return path;
  }

  @override
  Future<void> clear() async => cleared = true;
}

class FakeReport implements ReportService {
  int topicCount = 0;
  int flaggedCount = 0;

  @override
  Future<Uint8List> buildReport({
    required Analysis analysis,
    required List<TopicNode> weakTopics,
    required List<Reference> flagged,
  }) async {
    topicCount = weakTopics.length;
    flaggedCount = flagged.length;
    return Uint8List(2048);
  }
}

class FakeStorage implements StorageService {
  bool fail = false;
  String? uploadedName;

  @override
  Future<UploadedFile> uploadReport({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.64);
    if (fail) throw StateError('upload failed');
    uploadedName = fileName;
    return UploadedFile(
      path: 'reports/$uid/$fileName',
      url: 'https://files.test/$fileName',
    );
  }
}

class FakeFirestore implements FirestoreService {
  final reports = <String>[];
  final fcmTokens = <String>[];
  bool hangRead = false;
  bool failRead = false;
  bool hangEnsureUser = false;
  bool failEnsureUser = false;
  final readIds = <String>[];
  final _notifications = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> notifications = const [];

  @override
  Future<void> ensureUser(AppUser user) async {
    if (failEnsureUser) throw StateError('offline');
    if (hangEnsureUser) await Completer<void>().future;
  }

  @override
  Future<void> addFcmToken(String uid, String token) async =>
      fcmTokens.add('$uid:$token');
  @override
  Stream<List<AppNotification>> watchNotifications(String uid) {
    scheduleMicrotask(() => _notifications.add(notifications));
    return _notifications.stream;
  }

  @override
  Future<void> markNotificationRead(String uid, String id) async {
    if (failRead) throw StateError('offline');
    readIds.add(id);
    if (hangRead) await Completer<void>().future;
  }

  @override
  Future<void> addReport({
    required String uid,
    required String analysisId,
    required String storagePath,
    required String downloadUrl,
    required int sizeKb,
  }) async => reports.add(storagePath);
}

/// A reference with only the fields a test cares about.
Reference ref(
  String id,
  RefStatus status, {
  int index = 0,
  String? title,
  List<String> topicIds = const ['t'],
  List<ReferenceIssue> issues = const [],
}) => Reference(
  id: id,
  index: index,
  title: title ?? 'Paper $id',
  status: status,
  topicIds: topicIds,
  issues: issues,
);

Analysis doneAnalysis(
  String id, {
  StatusCounts counts = const StatusCounts(),
}) => Analysis(
  id: id,
  status: AnalysisStatus.done,
  title: 'Attention Is All You Need',
  counts: counts,
  totalRefs: counts.total,
);
