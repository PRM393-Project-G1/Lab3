import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_dependencies.dart';
import 'app_router.dart';
import 'app_routes.dart';
import 'firebase/analytics_service.dart';
import 'firebase/messaging_service.dart';
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

  runApp(await provideDependencies(child: const RealtronApp()));
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
        action: push.analysisId == null && !push.isAdminMessage
            ? null
            : SnackBarAction(label: 'View', onPressed: () => _openPush(push)),
      ),
    );
  }

  void _openPush(PushMessage push) {
    context.read<AnalyticsService>().logNotificationOpen(push.type);
    final id = push.analysisId;
    if (push.isAdminMessage) {
      _router.go(AppRoutes.notifications);
    } else if (id != null) {
      _router.go(AppRoutes.overview(id));
    }
  }

  void _openShared(String text) {
    _router.go(AppRoutes.analyzeShared(text));
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
