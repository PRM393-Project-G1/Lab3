import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract class CrashlyticsService {
  Future<void> setUser(String uid);
  Future<void> setKey(String key, Object value);
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  });
  void testCrash();
}

class FirebaseCrashlyticsService implements CrashlyticsService {
  FirebaseCrashlyticsService({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setUser(String uid) => _crashlytics.setUserIdentifier(uid);

  @override
  Future<void> setKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) => _crashlytics.recordError(error, stack, reason: reason, fatal: false);

  @override
  void testCrash() => _crashlytics.crash();

  /// Reports uncaught errors, from Flutter and from async code.
  void installHandlers() {
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
