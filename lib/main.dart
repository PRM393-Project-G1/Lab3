import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'firebase/analytics_service.dart';
import 'firebase/auth_service.dart';
import 'firebase/crashlytics_service.dart';
import 'firebase/firestore_service.dart';
import 'firebase/messaging_service.dart';
import 'firebase/remote_config_service.dart';
import 'firebase/storage_service.dart';
import 'services/analysis_repository.dart';
import 'services/api_client.dart';
import 'services/device_actions.dart';
import 'services/library_feed.dart';
import 'services/library_repository.dart';
import 'services/report_files.dart';
import 'services/report_service.dart';
import 'services/server_settings.dart';
import 'services/share_intent_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_view_model.dart';
import 'widgets/state_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // The build has no Firebase configuration, so nothing can work yet.
    runApp(const _SetupErrorApp());
    return;
  }

  final crashlytics = FirebaseCrashlyticsService()..installHandlers();
  FirebaseMessagingService.registerBackgroundHandler();
  final prefs = await SharedPreferences.getInstance();

  final auth = FirebaseAuthService();
  final analytics = FirebaseAnalyticsService();
  final firestore = CloudFirestoreService();
  final messaging = FirebaseMessagingService();
  final settings = ServerSettings(prefs);
  final remoteConfig = FirebaseRemoteConfigService();
  unawaited(remoteConfig.init());
  final analyses = FirestoreAnalysisRepository();
  final library = FirestoreLibraryRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: auth),
        Provider<AnalyticsService>.value(value: analytics),
        Provider<CrashlyticsService>.value(value: crashlytics),
        Provider<FirestoreService>.value(value: firestore),
        Provider<MessagingService>.value(value: messaging),
        Provider<StorageService>(create: (_) => FirebaseStorageService()),
        ChangeNotifierProvider<RemoteConfigService>.value(value: remoteConfig),
        ChangeNotifierProvider<ServerSettings>.value(value: settings),
        Provider<ApiClient>(
          create: (_) => HttpApiClient(settings: settings, auth: auth),
        ),
        Provider<AnalysisRepository>.value(value: analyses),
        Provider<LibraryRepository>.value(value: library),
        Provider<LibraryFeed>(create: (_) => LibraryFeed(library, analyses)),
        Provider<ReportService>(create: (_) => PdfReportService()),
        Provider<ReportFiles>(create: (_) => DeviceReportFiles()),
        Provider<DeviceActions>(create: (_) => SystemDeviceActions()),
        Provider<ShareIntentService>(create: (_) => SystemShareIntentService()),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(
            auth: auth,
            analytics: analytics,
            crashlytics: crashlytics,
            firestore: firestore,
            messaging: messaging,
          ),
        ),
      ],
      child: const RealtronApp(),
    ),
  );
}

class RealtronApp extends StatefulWidget {
  const RealtronApp({super.key});

  @override
  State<RealtronApp> createState() => _RealtronAppState();
}

class _RealtronAppState extends State<RealtronApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _subs = <StreamSubscription<Object?>>[];
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthViewModel>();
    _router = buildRouter(auth: auth, settings: context.read<ServerSettings>());

    final messaging = context.read<MessagingService>();
    _subs
      ..add(messaging.foreground.listen(_showForegroundPush))
      ..add(messaging.opened.listen(_openPush));

    final share = context.read<ShareIntentService>();
    _subs.add(share.incomingText.listen(_openShared));
    share.initialText().then((text) {
      if (text != null) _openShared(text);
    });

    // Last, so a push that launched the app finds its listener attached.
    auth.start();
  }

  void _showForegroundPush(PushMessage push) {
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(push.title),
        action: push.analysisId == null
            ? null
            : SnackBarAction(label: 'View', onPressed: () => _openPush(push)),
      ),
    );
  }

  void _openPush(PushMessage push) {
    context.read<AnalyticsService>().logNotificationOpen('analysis_done');
    if (push.analysisId != null) _router.go('/analyses/${push.analysisId}');
  }

  void _openShared(String text) {
    _router.go(
      Uri(path: '/analyze', queryParameters: {'shared': text}).toString(),
    );
    context.read<ShareIntentService>().clear();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Realtron',
    theme: buildAppTheme(),
    scaffoldMessengerKey: _messenger,
    routerConfig: _router,
  );
}

class _SetupErrorApp extends StatelessWidget {
  const _SetupErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Realtron',
    theme: buildAppTheme(),
    home: const Scaffold(
      body: StateView.error(title: 'Setup needed', actionLabel: null),
    ),
  );
}
