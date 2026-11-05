import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/app_router.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/models/app_notification.dart';
import 'package:realtron/models/library_entry.dart';
import 'package:realtron/services/library_feed.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:realtron/viewmodels/export_view_model.dart';
import 'package:realtron/viewmodels/history_view_model.dart';
import 'package:realtron/viewmodels/notifications_view_model.dart';
import 'package:realtron/viewmodels/profile_view_model.dart';
import 'package:realtron/viewmodels/view_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  const id = '1706.03762';

  group('History', () {
    late FakeLibrary library;
    late FakeAnalyses analyses;
    late FakeCrashlytics crashlytics;

    HistoryViewModel build() => HistoryViewModel(
      library: library,
      feed: LibraryFeed(library, analyses),
      auth: FakeAuth(),
      crashlytics: crashlytics,
    );

    setUp(() {
      library = FakeLibrary();
      analyses = FakeAnalyses();
      crashlytics = FakeCrashlytics();
    });

    test('a failed touch is logged, not thrown', () async {
      library.failWrites = true;

      await build().touch(
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5)),
      );

      expect(crashlytics.recorded, ['edit_history']);
    });

    test('an error on one paper keeps the list', () async {
      analyses.analyses[id] = doneAnalysis(id);
      library.entries = [
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5)),
      ];
      final vm = build();
      await pumpEventQueue();

      analyses.pushError(id);
      await pumpEventQueue();

      final entries = (vm.state as Data<List<LibraryEntry>>).value;
      expect(entries.single.arxivId, id);
      expect(entries.single.analysis, isNull);
    });

    test('no history is the empty state', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.state, isA<Empty<List<LibraryEntry>>>());
    });

    test('a stream error is a failure that can be retried', () async {
      final vm = build();
      await pumpEventQueue();
      library.emitError();
      await pumpEventQueue();
      expect(vm.state, isA<Failure<List<LibraryEntry>>>());

      vm.load();
      await pumpEventQueue();
      expect(vm.state, isA<Empty<List<LibraryEntry>>>());
    });

    test('groups by Today, This week and Earlier, newest first', () async {
      final now = DateTime(2026, 11, 5, 12);
      library.entries = [
        LibraryEntry(arxivId: 'old', addedAt: DateTime(2026, 10, 1)),
        LibraryEntry(arxivId: 'today1', addedAt: DateTime(2026, 11, 5, 8)),
        LibraryEntry(arxivId: 'today2', addedAt: DateTime(2026, 11, 5, 9)),
        LibraryEntry(arxivId: 'week', addedAt: DateTime(2026, 11, 2)),
        LibraryEntry(arxivId: 'edge', addedAt: DateTime(2026, 10, 29)),
      ];
      final vm = build();
      await pumpEventQueue();

      final groups = vm.groups(now: now);

      expect(groups.map((g) => g.period), [
        HistoryPeriod.today,
        HistoryPeriod.thisWeek,
        HistoryPeriod.earlier,
      ]);
      expect(groups[0].entries.map((e) => e.arxivId), ['today2', 'today1']);
      expect(groups[1].entries.map((e) => e.arxivId), ['week']);
      expect(groups[2].entries.map((e) => e.arxivId), ['edge', 'old']);
    });

    test('search covers the title and ID; no match means no groups', () async {
      analyses.analyses[id] = doneAnalysis(id);
      library.entries = [
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5)),
        LibraryEntry(
          arxivId: '2001.00001',
          customTitle: 'My notes',
          addedAt: DateTime(2026, 11, 5),
        ),
      ];
      final vm = build();
      await pumpEventQueue();

      vm.setQuery('attention');
      expect(vm.groups().single.entries.single.arxivId, id);

      vm.setQuery('2001');
      expect(vm.groups().single.entries.single.title, 'My notes');

      vm.setQuery('zzz');
      expect(vm.groups(), isEmpty);
      expect(vm.state, isA<Data<List<LibraryEntry>>>());
    });

    test('a running card updates when the backend finishes', () async {
      analyses.analyses[id] = const Analysis(
        id: id,
        status: AnalysisStatus.processing,
      );
      library.entries = [
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5)),
      ];
      final vm = build();
      await pumpEventQueue();
      expect(vm.groups().single.entries.single.analysis?.isRunning, isTrue);

      analyses.push(doneAnalysis(id));
      await pumpEventQueue();

      expect(vm.groups().single.entries.single.analysis?.isDone, isTrue);
    });

    test('delete removes only the history row', () async {
      analyses.analyses[id] = doneAnalysis(id);
      final vm = build();

      final deleted = await vm.delete(
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5)),
      );

      expect(deleted, isTrue);
      expect(library.removed, [id]);
      expect(analyses.analyses, contains(id));
    });

    test('rename trims the title; a failed write says so', () async {
      final entry = LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 5));
      final vm = build();

      expect(await vm.rename(entry, '  New name '), isTrue);
      expect(library.renamed[id], 'New name');

      library.failWrites = true;
      expect(await vm.rename(entry, 'Again'), isFalse);
      expect(await vm.delete(entry), isFalse);
    });
  });

  group('Notifications', () {
    final item = AppNotification(
      id: 'n1',
      title: 'Analysis done',
      body: 'Attention Is All You Need',
      createdAt: DateTime(2026, 11, 5),
      type: 'analysis_done',
      analysisId: id,
    );

    test('opening marks it read, logs it and returns the paper', () async {
      final firestore = FakeFirestore()..notifications = [item];
      final analytics = FakeAnalytics();
      final vm = NotificationsViewModel(
        firestore: firestore,
        auth: FakeAuth(),
        analytics: analytics,
        crashlytics: FakeCrashlytics(),
      );
      await pumpEventQueue();
      expect(vm.state, isA<Data<List<AppNotification>>>());

      expect(await vm.open(item), id);

      expect(firestore.readIds, ['n1']);
      expect(analytics.events, ['notification_open:analysis_done']);
    });

    test('a read mark that never finishes does not block opening', () async {
      final vm = NotificationsViewModel(
        firestore: FakeFirestore()..hangRead = true,
        auth: FakeAuth(),
        analytics: FakeAnalytics(),
        crashlytics: FakeCrashlytics(),
      );

      expect(await vm.open(item), id);
    });

    test('a failed read mark is logged and still opens', () async {
      final crashlytics = FakeCrashlytics();
      final vm = NotificationsViewModel(
        firestore: FakeFirestore()..failRead = true,
        auth: FakeAuth(),
        analytics: FakeAnalytics(),
        crashlytics: crashlytics,
      );

      expect(await vm.open(item), id);
      await pumpEventQueue();

      expect(crashlytics.recorded, ['mark_read']);
    });

    test('no notifications is the empty state', () async {
      final vm = NotificationsViewModel(
        firestore: FakeFirestore(),
        auth: FakeAuth(),
        analytics: FakeAnalytics(),
        crashlytics: FakeCrashlytics(),
      );
      await pumpEventQueue();
      expect(vm.state, isA<Empty<List<AppNotification>>>());
    });
  });

  group('Export', () {
    late FakeStorage storage;
    late FakeFirestore firestore;
    late FakeAnalytics analytics;
    late FakeCrashlytics crashlytics;
    late FakeDevice device;
    late FakeAnalyses analyses;
    late FakeReportFiles files;
    late FakeRemoteConfig remoteConfig;

    ExportViewModel build() => ExportViewModel(
      report: FakeReport(),
      files: files,
      storage: storage,
      firestore: firestore,
      analyses: analyses,
      remoteConfig: remoteConfig,
      auth: FakeAuth(),
      analytics: analytics,
      crashlytics: crashlytics,
      device: device,
      analysisId: id,
    );

    setUp(() {
      storage = FakeStorage();
      firestore = FakeFirestore();
      analytics = FakeAnalytics();
      crashlytics = FakeCrashlytics();
      device = FakeDevice();
      analyses = FakeAnalyses()..analyses[id] = doneAnalysis(id);
      files = FakeReportFiles();
      remoteConfig = FakeRemoteConfig();
    });

    test('with upload off, saves on the device and touches no cloud', () async {
      final vm = build();
      final phases = <ExportPhase>[];
      vm.addListener(() => phases.add(vm.phase));

      await vm.start();

      expect(phases, [ExportPhase.creating, ExportPhase.saved]);
      expect(files.saved, ['/files/u1/realtron_$id.pdf']);
      expect(storage.uploadedName, isNull);
      expect(firestore.reports, isEmpty);
      expect(crashlytics.recorded, isEmpty);
      expect(analytics.events, ['export_report']);
    });

    test('open and share use the saved file', () async {
      final vm = build();
      await vm.start();

      expect(await vm.open(), isTrue);
      await vm.share();

      expect(device.openedPdfs, ['/files/u1/realtron_$id.pdf']);
      expect(device.sharedPdfs, ['/files/u1/realtron_$id.pdf']);
      expect(device.shared, isEmpty);
    });

    test('open says so when no app can read PDF', () async {
      device.canOpenPdf = false;
      final vm = build();
      await vm.start();

      expect(await vm.open(), isFalse);
    });

    test('open does nothing before a file exists', () async {
      expect(await build().open(), isFalse);
      expect(device.openedPdfs, isEmpty);
    });

    test('a failed save is reported, and Retry works', () async {
      files.fail = true;
      final vm = build();

      await vm.start();

      expect(vm.phase, ExportPhase.failed);
      expect(crashlytics.recorded, ['export_report']);
      expect(analytics.events, isEmpty);

      files.fail = false;
      await vm.start();
      expect(vm.phase, ExportPhase.saved);
    });

    test('creates, uploads under the user and records metadata', () async {
      remoteConfig.enableCloudUpload = true;
      final vm = build();
      final phases = <ExportPhase>[];
      vm.addListener(() => phases.add(vm.phase));

      await vm.start();

      expect(
        phases,
        containsAllInOrder([
          ExportPhase.creating,
          ExportPhase.uploading,
          ExportPhase.uploaded,
        ]),
      );
      expect(storage.uploadedName, 'realtron_$id.pdf');
      expect(firestore.reports, ['reports/u1/realtron_$id.pdf']);
      expect(vm.fileLabel, 'realtron_$id.pdf · 2 KB');
      expect(analytics.events, ['export_report']);
    });

    test('an upload failure is reported, and Retry works', () async {
      remoteConfig.enableCloudUpload = true;
      storage.fail = true;
      final vm = build();

      await vm.start();

      expect(vm.phase, ExportPhase.failed);
      expect(crashlytics.recorded, ['export_report']);
      expect(firestore.reports, isEmpty);
      expect(analytics.events, isEmpty);

      storage.fail = false;
      await vm.start();
      expect(vm.phase, ExportPhase.uploaded);
    });

    test('copy and share use the uploaded link', () async {
      remoteConfig.enableCloudUpload = true;
      final vm = build();
      await vm.start();

      await vm.copyLink();
      await vm.share();

      expect(device.clipboard, 'https://files.test/realtron_$id.pdf');
      expect(device.shared, ['https://files.test/realtron_$id.pdf']);
    });
  });

  group('Profile', () {
    late FakeAuth auth;
    late ServerSettings settings;
    late FakeAnalytics analytics;
    late FakeCrashlytics crashlytics;
    late FakeLibrary library;
    late FakeAnalyses analyses;
    late FakeReportFiles files;
    late FakeMessaging messaging;

    ProfileViewModel build() => ProfileViewModel(
      auth: auth,
      settings: settings,
      remoteConfig: FakeRemoteConfig(),
      analytics: analytics,
      crashlytics: crashlytics,
      files: files,
      messaging: messaging,
      feed: LibraryFeed(library, analyses),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({'server_url': 'http://a.test'});
      auth = FakeAuth();
      settings = ServerSettings(await SharedPreferences.getInstance());
      analytics = FakeAnalytics();
      crashlytics = FakeCrashlytics();
      library = FakeLibrary();
      analyses = FakeAnalyses();
      files = FakeReportFiles();
      messaging = FakeMessaging();
    });

    test('shows the five Remote Config values', () {
      expect(build().remoteConfigRows.map((row) => row.$1), [
        'weak_topic_threshold',
        'weak_topic_min_refs',
        'max_recent_checks',
        'enable_report_export',
        'enable_cloud_upload',
      ]);
    });

    test('Export uses the newest finished analysis', () async {
      analyses.analyses[id] = doneAnalysis(id);
      analyses.analyses['running'] = const Analysis(
        id: 'running',
        status: AnalysisStatus.processing,
      );
      library.entries = [
        LibraryEntry(arxivId: 'running', addedAt: DateTime(2026, 11, 5)),
        LibraryEntry(arxivId: id, addedAt: DateTime(2026, 11, 4)),
      ];
      final vm = build();
      await pumpEventQueue();

      expect(vm.latestDoneId, id);
    });

    test('Log error records a non-fatal; Test crash crashes', () async {
      final vm = build();

      await vm.logError();
      vm.testCrash();

      expect(crashlytics.recorded, ['firebase_demo']);
      expect(crashlytics.crashed, isTrue);
    });

    test('sign out removes the device token', () async {
      await build().signOut();

      expect(messaging.deleted, isTrue);
      expect(auth.signedOut, isTrue);
    });

    test('sign out still works when the token cannot be removed', () async {
      messaging.failDelete = true;

      await build().signOut();

      expect(auth.signedOut, isTrue);
      expect(crashlytics.recorded, ['delete_token']);
    });

    test('sign out logs it and clears local user data', () async {
      final vm = build();

      await vm.signOut();

      expect(analytics.events, ['logout']);
      expect(auth.signedOut, isTrue);
      expect(settings.serverUrl, isNull);
      expect(files.cleared, isTrue);
    });
  });

  group('Router gate', () {
    String? gate({
      required bool signedIn,
      required bool server,
      String? path,
    }) => gateRedirect(
      signedIn: signedIn,
      hasServer: server,
      path: path ?? '/analyze',
    );

    test('not signed in always goes to sign-in', () {
      expect(gate(signedIn: false, server: true), '/sign-in');
      expect(gate(signedIn: false, server: false, path: '/sign-in'), isNull);
    });

    test('no saved server goes to connect', () {
      expect(gate(signedIn: true, server: false), '/connect');
      expect(gate(signedIn: true, server: false, path: '/connect'), isNull);
    });

    test('a finished setup leaves the entry screens', () {
      expect(gate(signedIn: true, server: true, path: '/sign-in'), '/analyze');
      expect(gate(signedIn: true, server: true, path: '/connect'), '/analyze');
      expect(gate(signedIn: true, server: true), isNull);
    });
  });
}
