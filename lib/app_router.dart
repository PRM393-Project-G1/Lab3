import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'screens/analyze_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_shell.dart';
import 'screens/notifications_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reference_detail_screen.dart';
import 'screens/reference_list_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/topic_detail_screen.dart';
import 'screens/topic_map_screen.dart';
import 'services/library_feed.dart';
import 'services/server_settings.dart';
import 'viewmodels/analyze_view_model.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/connect_view_model.dart';
import 'viewmodels/history_view_model.dart';
import 'viewmodels/notifications_view_model.dart';
import 'viewmodels/overview_view_model.dart';
import 'viewmodels/profile_view_model.dart';
import 'viewmodels/progress_view_model.dart';
import 'viewmodels/reference_detail_view_model.dart';
import 'viewmodels/reference_list_view_model.dart';
import 'viewmodels/topic_detail_view_model.dart';
import 'viewmodels/topic_map_view_model.dart';

/// Not signed in goes to Sign-in; no saved server goes to Connect.
String? gateRedirect({
  required bool signedIn,
  required bool hasServer,
  required String path,
}) {
  if (!signedIn) return path == AppRoutes.signIn ? null : AppRoutes.signIn;
  if (!hasServer) return path == AppRoutes.connect ? null : AppRoutes.connect;
  if (path == AppRoutes.signIn || path == AppRoutes.connect) {
    return AppRoutes.analyze;
  }
  return null;
}

GoRouter buildRouter({
  required AuthViewModel auth,
  required ServerSettings settings,
}) {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();

  Widget connect({bool fromProfile = false}) => ChangeNotifierProvider(
    create: (c) => ConnectViewModel(
      api: c.read(),
      settings: c.read(),
      device: c.read(),
      crashlytics: c.read(),
    ),
    child: ConnectScreen(fromProfile: fromProfile),
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.analyze,
    refreshListenable: Listenable.merge([auth, settings]),
    redirect: (_, state) => gateRedirect(
      signedIn: auth.isSignedIn,
      hasServer: settings.serverUrl != null,
      path: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRoutes.connect, builder: (_, _) => connect()),
      GoRoute(
        path: AppRoutes.serverSettings,
        parentNavigatorKey: rootKey,
        builder: (_, _) => connect(fromProfile: true),
      ),
      GoRoute(
        path: AppRoutes.progress(':id'),
        parentNavigatorKey: rootKey,
        builder: (_, state) => ChangeNotifierProvider(
          create: (c) => ProgressViewModel(
            analyses: c.read(),
            api: c.read(),
            settings: c.read(),
            analysisId: state.pathParameters['id']!,
          ),
          child: const ProgressScreen(),
        ),
      ),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (_, state, child) =>
            HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.analyze,
            builder: (_, state) {
              final shared = state.uri.queryParameters['shared'];
              return ChangeNotifierProvider(
                // A new share starts a fresh form.
                key: ValueKey(shared),
                create: (c) => AnalyzeViewModel(
                  api: c.read(),
                  analyses: c.read(),
                  library: c.read(),
                  feed: c.read<LibraryFeed>(),
                  auth: c.read(),
                  settings: c.read(),
                  remoteConfig: c.read(),
                  analytics: c.read(),
                  crashlytics: c.read(),
                  device: c.read(),
                  sharedText: shared,
                ),
                child: AnalyzeScreen(key: ValueKey('analyze-$shared')),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, _) => ChangeNotifierProvider(
              create: (c) => HistoryViewModel(
                library: c.read(),
                feed: c.read<LibraryFeed>(),
                auth: c.read(),
                crashlytics: c.read(),
              ),
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, _) => ChangeNotifierProvider(
              create: (c) => ProfileViewModel(
                auth: c.read(),
                settings: c.read(),
                remoteConfig: c.read(),
                analytics: c.read(),
                crashlytics: c.read(),
                files: c.read(),
                messaging: c.read(),
                feed: c.read<LibraryFeed>(),
              ),
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => ChangeNotifierProvider(
              create: (c) => NotificationsViewModel(
                firestore: c.read(),
                auth: c.read(),
                analytics: c.read(),
                crashlytics: c.read(),
              ),
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.overview(':id'),
            builder: (_, state) => ChangeNotifierProvider(
              create: (c) => OverviewViewModel(
                analyses: c.read(),
                remoteConfig: c.read(),
                analytics: c.read(),
                crashlytics: c.read(),
                analysisId: state.pathParameters['id']!,
              ),
              child: const OverviewScreen(),
            ),
            routes: [
              GoRoute(
                path: 'topics',
                builder: (_, state) => ChangeNotifierProvider(
                  create: (c) => TopicMapViewModel(
                    analyses: c.read(),
                    remoteConfig: c.read(),
                    analytics: c.read(),
                    analysisId: state.pathParameters['id']!,
                  ),
                  child: const TopicMapScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':topicId',
                    builder: (_, state) => ChangeNotifierProvider(
                      create: (c) => TopicDetailViewModel(
                        analyses: c.read(),
                        remoteConfig: c.read(),
                        analytics: c.read(),
                        analysisId: state.pathParameters['id']!,
                        topicId: state.pathParameters['topicId']!,
                      ),
                      child: const TopicDetailScreen(),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'references',
                builder: (_, state) => ChangeNotifierProvider(
                  create: (c) => ReferenceListViewModel(
                    analyses: c.read(),
                    analysisId: state.pathParameters['id']!,
                    filter: state.uri.queryParameters['filter'],
                  ),
                  child: const ReferenceListScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':refId',
                    builder: (_, state) => ChangeNotifierProvider(
                      create: (c) => ReferenceDetailViewModel(
                        analyses: c.read(),
                        device: c.read(),
                        analytics: c.read(),
                        analysisId: state.pathParameters['id']!,
                        referenceId: state.pathParameters['refId']!,
                      ),
                      child: const ReferenceDetailScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
