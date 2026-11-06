import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase/analytics_service.dart';
import 'firebase/auth_service.dart';
import 'firebase/crashlytics_service.dart';
import 'firebase/firestore_service.dart';
import 'firebase/messaging_service.dart';
import 'firebase/remote_config_service.dart';
import 'firebase/storage_service.dart';
import 'services/analysis_repository.dart';
import 'services/api_client.dart';
import 'services/cloudinary_storage_service.dart';
import 'services/device_actions.dart';
import 'services/library_feed.dart';
import 'services/library_repository.dart';
import 'services/report_files.dart';
import 'services/report_service.dart';
import 'services/server_settings.dart';
import 'services/share_intent_service.dart';
import 'viewmodels/auth_view_model.dart';

/// Composition root: the one place that names concrete services. Everything
/// else asks Provider for an interface, which is how the tests hand in fakes.
///
/// Call after `Firebase.initializeApp`.
Future<Widget> provideDependencies({required Widget child}) async {
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
  final api = HttpApiClient(settings: settings, auth: auth);

  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: auth),
      Provider<AnalyticsService>.value(value: analytics),
      Provider<CrashlyticsService>.value(value: crashlytics),
      Provider<FirestoreService>.value(value: firestore),
      Provider<MessagingService>.value(value: messaging),
      // Cloudinary until the Firebase project has a Storage bucket; then
      // FirebaseStorageService() again. See cloudinary_storage_service.dart.
      Provider<StorageService>(
        create: (_) => CloudinaryStorageService(api: api),
      ),
      ChangeNotifierProvider<RemoteConfigService>.value(value: remoteConfig),
      ChangeNotifierProvider<ServerSettings>.value(value: settings),
      Provider<ApiClient>.value(value: api),
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
    child: child,
  );
}
