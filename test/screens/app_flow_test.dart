import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:realtron/app_router.dart';
import 'package:realtron/firebase/analytics_service.dart';
import 'package:realtron/firebase/auth_service.dart';
import 'package:realtron/firebase/crashlytics_service.dart';
import 'package:realtron/firebase/firestore_service.dart';
import 'package:realtron/firebase/messaging_service.dart';
import 'package:realtron/firebase/remote_config_service.dart';
import 'package:realtron/firebase/storage_service.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/models/app_notification.dart';
import 'package:realtron/models/library_entry.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/reference.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/services/analysis_repository.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/device_actions.dart';
import 'package:realtron/services/library_feed.dart';
import 'package:realtron/services/library_repository.dart';
import 'package:realtron/services/report_files.dart';
import 'package:realtron/services/report_service.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:realtron/theme/app_theme.dart';
import 'package:realtron/viewmodels/auth_view_model.dart';
import 'package:realtron/widgets/app_filter_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// For the running progress screen, whose spinner never settles.
Future<void> settleSome(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  const id = '1706.03762';

  late FakeAuth auth;
  late FakeApi api;
  late FakeAnalyses analyses;
  late FakeLibrary library;
  late FakeAnalytics analytics;
  late FakeCrashlytics crashlytics;
  late FakeRemoteConfig remoteConfig;
  late FakeDevice device;
  late FakeStorage storage;
  late FakeReportFiles files;
  late FakeFirestore firestore;
  late ServerSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://a.test'});
    settings = ServerSettings(await SharedPreferences.getInstance());
    auth = FakeAuth();
    api = FakeApi();
    library = FakeLibrary();
    analytics = FakeAnalytics();
    crashlytics = FakeCrashlytics();
    remoteConfig = FakeRemoteConfig();
    device = FakeDevice();
    storage = FakeStorage();
    files = FakeReportFiles();
    firestore = FakeFirestore();
    analyses = FakeAnalyses()
      ..analyses[id] = doneAnalysis(
        id,
        counts: const StatusCounts(hallucinated: 2, error: 1, verified: 2),
      )
      ..references[id] = [
        const Reference(
          id: 'h1',
          index: 1,
          title: 'A paper that does not exist',
          status: RefStatus.hallucinated,
          topicIds: ['weak'],
          hallucinationNote: 'No matching record was found.',
          closestMatchTitle: 'A paper that exists',
          closestMatchUrl: 'https://arxiv.org/abs/1409.0473',
        ),
        ref('h2', RefStatus.hallucinated, index: 2, topicIds: const ['weak']),
        const Reference(
          id: 'e1',
          index: 3,
          title: 'Sequence to sequence learning',
          status: RefStatus.error,
          authors: ['Sutskever', 'Vinyals', 'Le'],
          year: 2014,
          url: 'https://arxiv.org/abs/1409.3215',
          topicIds: ['weak'],
          issues: [
            ReferenceIssue(
              type: 'year',
              message: 'Year differs',
              cited: '2013',
              actual: '2014',
            ),
          ],
        ),
        ref('v1', RefStatus.verified, index: 4, topicIds: const ['fine']),
        ref('v2', RefStatus.verified, index: 5, topicIds: const []),
      ]
      ..topics[id] = const [
        Topic(id: 'root', term: 'Sequence models'),
        Topic(
          id: 'weak',
          term: 'Attention',
          parentId: 'root',
          refIds: ['h1', 'h2', 'e1'],
        ),
        Topic(id: 'fine', term: 'Optimizers', parentId: 'root', refIds: ['v1']),
      ];
  });

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    double width = 360,
    double height = 1600,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);

    final messaging = FakeMessaging();
    final authVm = AuthViewModel(
      auth: auth,
      analytics: analytics,
      crashlytics: crashlytics,
      firestore: firestore,
      messaging: messaging,
    )..start();
    final router = buildRouter(auth: authVm, settings: settings);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: auth),
          Provider<AnalyticsService>.value(value: analytics),
          Provider<CrashlyticsService>.value(value: crashlytics),
          Provider<FirestoreService>.value(value: firestore),
          Provider<StorageService>.value(value: storage),
          Provider<MessagingService>.value(value: messaging),
          ChangeNotifierProvider<RemoteConfigService>.value(
            value: remoteConfig,
          ),
          ChangeNotifierProvider<ServerSettings>.value(value: settings),
          Provider<ApiClient>.value(value: api),
          Provider<AnalysisRepository>.value(value: analyses),
          Provider<LibraryRepository>.value(value: library),
          Provider<LibraryFeed>.value(value: LibraryFeed(library, analyses)),
          Provider<ReportService>.value(value: FakeReport()),
          Provider<ReportFiles>.value(value: files),
          Provider<DeviceActions>.value(value: device),
          ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(useGoogleFonts: false),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('entry', () {
    testWidgets('signed out only reaches sign-in, then Analyze', (
      tester,
    ) async {
      auth.currentUser = null;
      auth.result = SignInResult.cancelled;
      final router = await pumpApp(tester);

      router.go('/history');
      await tester.pumpAndSettle();
      expect(find.text('Know what a paper stands on.'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Sign-in cancelled'), findsOneWidget);

      auth.result = SignInResult.offline;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);

      auth.result = SignInResult.disabled;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('This account is disabled'), findsOneWidget);
      expect(
        find.textContaining('An administrator disabled it'),
        findsOneWidget,
      );

      auth.result = SignInResult.success;
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('arXiv ID or link'), findsOneWidget);
      expect(analytics.events, contains('login'));
    });

    testWidgets('first run connects before anything else', (tester) async {
      await settings.clear();
      await pumpApp(tester);
      expect(find.text('Connect server'), findsOneWidget);

      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a server URL'), findsOneWidget);

      final field = find.byType(TextField);
      await tester.enterText(field, '100.1.2.3:8000');
      api.failure = ApiFailure.unreachable;
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.text("Can't reach server"), findsOneWidget);
      expect(find.text('Tailscale on?'), findsOneWidget);

      api.failure = ApiFailure.timeout;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Timed out'), findsOneWidget);

      api.failure = ApiFailure.notRealtron;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Not a Realtron server'), findsOneWidget);

      api.failure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Connected · 84 ms'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('arXiv ID or link'), findsOneWidget);
      expect(settings.serverUrl, 'http://100.1.2.3:8000');
    });
  });

  group('Flow A', () {
    testWidgets('invalid ID locks the button; the example chip fills it', (
      tester,
    ) async {
      analyses.analyses.clear();
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      expect(find.text('Not a valid arXiv ID'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Analyze'))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Try $id'));
      await tester.pump();
      expect(find.text('Not a valid arXiv ID'), findsNothing);
    });

    testWidgets('new paper: progress, done, results', (tester) async {
      analyses.analyses.remove(id);
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), id);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Analyze'));
      await settleSome(tester);

      expect(api.started, [id]);
      expect(find.text('Analyzing…'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      analyses.push(
        const Analysis(
          id: id,
          status: AnalysisStatus.processing,
          totalRefs: 41,
          progress: AnalysisProgress(
            stage: AnalysisStage.verify,
            percent: 44,
            processedRefs: 18,
          ),
        ),
      );
      await settleSome(tester);
      expect(find.text('18/41 refs'), findsOneWidget);
      expect(find.text('Fabrication check'), findsOneWidget);

      analyses.push(
        doneAnalysis(
          id,
          counts: const StatusCounts(hallucinated: 2, error: 1, verified: 2),
        ),
      );
      await settleSome(tester);
      await tester.tap(find.text('View results'));
      await tester.pumpAndSettle();

      expect(find.text('Paper Overview'), findsOneWidget);
      expect(find.text('2 may be fabricated'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('analyzed before: opens results directly', (tester) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'arxiv.org/abs/$id');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Analyze'));
      await tester.pumpAndSettle();

      expect(find.text('Paper Overview'), findsOneWidget);
      expect(api.started, isEmpty);
    });

    testWidgets('server down shows the fix and offers another server', (
      tester,
    ) async {
      analyses.analyses.remove(id);
      api.failure = ApiFailure.unreachable;
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), id);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Analyze'));
      await tester.pumpAndSettle();

      expect(find.text("Can't reach server"), findsOneWidget);
      expect(find.text('Check Tailscale and backend.'), findsOneWidget);

      await tester.tap(find.text('Change server'));
      await tester.pumpAndSettle();
      expect(find.text('Connect server'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('failure offers Retry and Edit; Stop asks first', (
      tester,
    ) async {
      analyses.analyses[id] = const Analysis(
        id: id,
        status: AnalysisStatus.processing,
      );
      final router = await pumpApp(tester);
      router.go('/analyses/$id/progress');
      await settleSome(tester);

      await tester.tap(find.text('Stop'));
      await settleSome(tester);
      expect(find.text('Stop analysis?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await settleSome(tester);
      expect(api.cancelled, isEmpty);

      await tester.tap(find.text('Stop'));
      await settleSome(tester);
      await tester.tap(find.text('Stop').last);
      await settleSome(tester);
      expect(api.cancelled, [id]);

      router.go('/analyses/$id/progress');
      await settleSome(tester);
      analyses.push(
        const Analysis(
          id: id,
          status: AnalysisStatus.failed,
          error: 'PDF not found',
        ),
      );
      await settleSome(tester);
      expect(find.text('Analysis failed'), findsOneWidget);
      expect(find.text('PDF not found'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await settleSome(tester);
      expect(find.text('arXiv ID or link'), findsOneWidget);
    });
  });

  group('Flow B', () {
    testWidgets('overview to topics to a reference', (tester) async {
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();
      expect(find.text('3 topics · 2 weak'), findsOneWidget);

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.text('Topics'), findsOneWidget);
      expect(find.text('Unclassified · 1'), findsOneWidget);
      expect(find.text('No readable text'), findsOneWidget);
      expect(find.text('Weak: ≥ 50% refs have issues'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppFilterChip, 'Weak'));
      await tester.pumpAndSettle();
      expect(find.text('Optimizers'), findsNothing);
      expect(find.text('Unclassified · 1'), findsNothing);

      await tester.tap(find.text('Attention'));
      await tester.pumpAndSettle();
      expect(find.text('Sequence models'), findsOneWidget);
      expect(find.text('Sequence to sequence learning'), findsOneWidget);

      await tester.tap(find.text('Sequence to sequence learning'));
      await tester.pumpAndSettle();
      expect(find.text('Cited'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);

      await tester.tap(find.text('Copy fix'));
      await tester.pumpAndSettle();
      expect(find.text('Fix copied'), findsOneWidget);
      expect(device.clipboard, 'year: 2013 -> 2014');

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(device.opened, ['https://arxiv.org/abs/1409.3215']);
    });

    testWidgets('a fabricated reference opens its dialog by itself', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/analyses/$id/references?filter=hallucinated');
      await tester.pumpAndSettle();
      expect(find.text('Sequence to sequence learning'), findsNothing);

      await tester.tap(find.text('A paper that does not exist'));
      await tester.pumpAndSettle();
      expect(find.text('Closest match'), findsOneWidget);
      expect(find.text('May be wrong — check the source.'), findsOneWidget);

      await tester.tap(find.text('Search web'));
      await tester.pumpAndSettle();
      expect(device.searched, ['A paper that does not exist']);
    });

    testWidgets('no weak topics offers Show all', (tester) async {
      remoteConfig.weakTopicMinRefs = 50;
      final router = await pumpApp(tester);
      router.go('/analyses/$id/topics');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppFilterChip, 'Weak'));
      await tester.pumpAndSettle();
      expect(find.text('No weak topics'), findsOneWidget);

      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('Attention'), findsOneWidget);
    });

    testWidgets('a load error can be retried', (tester) async {
      analyses.fail = true;
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load"), findsOneWidget);

      analyses.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('2 may be fabricated'), findsOneWidget);
    });

    testWidgets('opened with no history, Back leads to History', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('No checks yet'), findsOneWidget);
      expect(router.state.uri.path, '/history');
    });
  });

  group('Flow C', () {
    testWidgets('admin announcement opens its full message and marks it read', (
      tester,
    ) async {
      const body =
          'Realtron will receive a maintenance update. Your existing paper results remain available.';
      firestore.notifications = [
        AppNotification(
          id: 'admin-notice',
          title: 'A message from Realtron',
          body: body,
          type: 'admin_message',
          createdAt: DateTime.now(),
        ),
      ];
      final router = await pumpApp(tester);
      router.go('/notifications');
      await tester.pumpAndSettle();
      await tester.tap(find.text('A message from Realtron'));
      await tester.pumpAndSettle();
      expect(firestore.readIds, ['admin-notice']);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(body),
        ),
        findsOneWidget,
      );
      expect(router.state.uri.path, '/notifications');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    setUp(() {
      library.entries = [LibraryEntry(arxivId: id, addedAt: DateTime.now())];
    });

    testWidgets('history opens results, and the report saves on the device', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/history');
      await tester.pumpAndSettle();
      expect(find.text('TODAY'), findsOneWidget);

      await tester.tap(find.text('Attention Is All You Need'));
      await tester.pumpAndSettle();
      expect(find.text('Paper Overview'), findsOneWidget);
      expect(library.touched, [id]);

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Saved on device'), findsOneWidget);
      expect(find.text('Copy link'), findsNothing);
      expect(find.text('realtron_$id.pdf · 2 KB'), findsOneWidget);
      expect(files.saved, ['/files/u1/realtron_$id.pdf']);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(device.openedPdfs, ['/files/u1/realtron_$id.pdf']);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(device.sharedPdfs, ['/files/u1/realtron_$id.pdf']);
    });

    testWidgets('with no PDF app, Open explains and closes the sheet', (
      tester,
    ) async {
      device.canOpenPdf = false;
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('No app can open PDF'), findsOneWidget);
      expect(find.text('Saved on device'), findsNothing);
    });

    testWidgets('with upload on, the report uploads and gives a link', (
      tester,
    ) async {
      remoteConfig.enableCloudUpload = true;
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Uploaded'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(device.shared, ['https://files.test/realtron_$id.pdf']);

      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(find.text('Link copied'), findsOneWidget);
      expect(device.clipboard, 'https://files.test/realtron_$id.pdf');
    });

    testWidgets('a failed upload offers Retry', (tester) async {
      remoteConfig.enableCloudUpload = true;
      storage.fail = true;
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Export failed'), findsOneWidget);
      expect(crashlytics.recorded, ['export_report']);

      storage.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Uploaded'), findsOneWidget);
    });

    testWidgets('enable_report_export hides Report', (tester) async {
      remoteConfig.enableReportExport = false;
      final router = await pumpApp(tester);
      router.go('/analyses/$id');
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsNothing);
    });

    testWidgets('a running card opens progress', (tester) async {
      analyses.analyses[id] = const Analysis(
        id: id,
        status: AnalysisStatus.processing,
        title: 'Running paper',
      );
      final router = await pumpApp(tester);
      router.go('/history');
      await tester.pumpAndSettle();
      expect(find.text('Running'), findsOneWidget);

      await tester.tap(find.text('Running paper'));
      await settleSome(tester);
      expect(find.text('Analyzing…'), findsOneWidget);
    });

    testWidgets('search, rename and delete', (tester) async {
      final router = await pumpApp(tester);
      router.go('/history');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'My title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(library.renamed[id], 'My title');

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete check?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(library.removed, [id]);
      expect(find.text('Deleted'), findsOneWidget);
    });

    testWidgets('empty history links back to Analyze', (tester) async {
      library.entries = const [];
      final router = await pumpApp(tester);
      router.go('/history');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Analyze a paper'));
      await tester.pumpAndSettle();
      expect(find.text('arXiv ID or link'), findsOneWidget);
    });

    testWidgets('a notification opens its paper', (tester) async {
      firestore.notifications = [
        AppNotification(
          id: 'n1',
          title: 'Analysis done',
          body: 'Attention Is All You Need · 2 flagged',
          createdAt: DateTime.now(),
          type: 'analysis_done',
          analysisId: id,
        ),
      ];
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analysis done'));
      await tester.pumpAndSettle();

      expect(firestore.readIds, ['n1']);
      expect(find.text('Paper Overview'), findsOneWidget);
    });
  });

  group('Profile', () {
    testWidgets('Firebase demo works and sign-out leaves', (tester) async {
      final router = await pumpApp(tester);
      router.go('/profile');
      await tester.pumpAndSettle();

      expect(find.text('FIREBASE DEMO'), findsOneWidget);
      expect(find.text('weak_topic_threshold'), findsOneWidget);
      expect(find.text('http://a.test'), findsOneWidget);

      await tester.tap(find.text('Export report'));
      await tester.pumpAndSettle();
      expect(find.text('No checks yet'), findsOneWidget);

      await tester.tap(find.text('Log error'));
      await tester.pumpAndSettle();
      expect(crashlytics.recorded, ['firebase_demo']);

      await tester.tap(find.text('Test crash'));
      await tester.pumpAndSettle();
      expect(find.text('The app will close.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(crashlytics.crashed, isFalse);

      await tester.tap(find.text('Test crash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crash'));
      await tester.pumpAndSettle();
      expect(crashlytics.crashed, isTrue);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Connect server'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(analytics.events, contains('logout'));
      expect(settings.serverUrl, isNull);
    });

    testWidgets('the tabs switch screens', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('No checks yet'), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('FIREBASE DEMO'), findsOneWidget);
      await tester.tap(find.text('Analyze').last);
      await tester.pumpAndSettle();
      expect(find.text('arXiv ID or link'), findsOneWidget);
    });
  });

  group('layout', () {
    const routes = [
      '/analyze',
      '/history',
      '/profile',
      '/notifications',
      '/profile/server',
      '/analyses/$id',
      '/analyses/$id/topics',
      '/analyses/$id/topics/weak',
      '/analyses/$id/references',
      '/analyses/$id/references/e1',
      '/analyses/$id/progress',
    ];

    for (final width in const [360.0, 412.0]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('no overflow at $width dp, text scale $scale', (
          tester,
        ) async {
          library.entries = [
            LibraryEntry(arxivId: id, addedAt: DateTime.now()),
          ];
          final router = await pumpApp(
            tester,
            width: width,
            height: 640,
            textScale: scale,
          );
          for (final route in routes) {
            router.go(route);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: route);
          }
        });
      }
    }
  });
}
