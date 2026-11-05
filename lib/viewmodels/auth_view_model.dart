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
    unawaited(_report(_identify(user)));
    if (user == null) return;
    // Separate, because a Firestore write can wait for the network for as
    // long as the phone is offline, and pushes must still arrive meanwhile.
    final ensured = _firestore.ensureUser(user);
    unawaited(_report(ensured));
    unawaited(
      _report(
        _messaging.start((token) async {
          // ensureUser only sets `role` on a document that does not exist yet.
          await ensured;
          final uid = _user?.uid;
          if (uid != null) await _firestore.addFcmToken(uid, token);
        }),
      ),
    );
  }

  Future<void> _identify(AppUser? user) async {
    await _analytics.setUser(user?.uid);
    await _crashlytics.setUser(user?.uid ?? '');
  }

  Future<void> _report(Future<void> work) async {
    try {
      await work;
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
