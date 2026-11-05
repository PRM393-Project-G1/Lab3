import 'dart:async';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/crashlytics_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/messaging_service.dart';
import '../models/app_user.dart';
import 'base_view_model.dart';

/// Who is signed in. Also drives the router, so it lives for the whole app.
class AuthViewModel extends BaseViewModel {
  AuthViewModel({
    required AuthService auth,
    required this._analytics,
    required this._crashlytics,
    required this._firestore,
    required this._messaging,
  }) : _auth = auth,
       _user = auth.currentUser;

  final AuthService _auth;
  final AnalyticsService _analytics;
  final CrashlyticsService _crashlytics;
  final FirestoreService _firestore;
  final MessagingService _messaging;

  StreamSubscription<AppUser?>? _userSub;
  AppUser? _user;
  bool _signingIn = false;
  SignInResult? _lastResult;
  bool _messagingStarted = false;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get signingIn => _signingIn;

  /// The problem to show on the sign-in screen, if any.
  SignInResult? get problem =>
      _lastResult == SignInResult.success ? null : _lastResult;

  /// Call after listeners for opened pushes are attached.
  void start() {
    _userSub ??= _auth.userChanges.listen(_onUser);
  }

  Future<void> signIn() async {
    _signingIn = true;
    _lastResult = null;
    notifyListeners();
    _lastResult = await _auth.signInWithGoogle();
    _signingIn = false;
    if (_lastResult == SignInResult.success) {
      await _analytics.logLogin();
    }
    notifyListeners();
  }

  void _onUser(AppUser? user) {
    _user = user;
    notifyListeners();
    unawaited(_syncUser(user));
  }

  Future<void> _syncUser(AppUser? user) async {
    try {
      await _analytics.setUser(user?.uid);
      await _crashlytics.setUser(user?.uid ?? '');
      if (user == null) return;
      await _firestore.ensureUser(user);
      if (!_messagingStarted) {
        _messagingStarted = true;
        await _messaging.start((token) async {
          final uid = _user?.uid;
          if (uid != null) await _firestore.addFcmToken(uid, token);
        });
      }
    } catch (error, stack) {
      await _crashlytics.recordNonFatal(error, stack, reason: 'sync_user');
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
