import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

enum SignInResult {
  success,
  cancelled,
  offline,
  failed,

  /// An administrator disabled the account in the admin web.
  disabled,
}

abstract class AuthService {
  Stream<AppUser?> get userChanges;
  AppUser? get currentUser;
  Future<SignInResult> signInWithGoogle();
  Future<void> signOut();
  Future<String?> idToken();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  bool _googleReady = false;

  AppUser? _map(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<SignInResult> signInWithGoogle() async {
    try {
      if (!_googleReady) {
        await _google.initialize();
        _googleReady = true;
      }
      final account = await _google.authenticate();
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
      return SignInResult.success;
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? SignInResult.cancelled
          : SignInResult.failed;
    } on SocketException {
      return SignInResult.offline;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'network-request-failed' => SignInResult.offline,
        'user-disabled' => SignInResult.disabled,
        _ => SignInResult.failed,
      };
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleReady) await _google.signOut();
  }

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();
}
