import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// A push the user can act on.
class PushMessage {
  const PushMessage({required this.title, this.body, this.analysisId});

  final String title;
  final String? body;
  final String? analysisId;
}

abstract class MessagingService {
  /// Pushes received while the app is open.
  Stream<PushMessage> get foreground;

  /// Pushes the user tapped, from the background or a terminated app.
  Stream<PushMessage> get opened;

  /// Registers this device for the signed-in user. Call it for every sign-in.
  Future<void> start(Future<void> Function(String token) onToken);

  /// Stops pushes to this device, so the next user does not get them.
  Future<void> deleteToken();
}

/// Runs in its own isolate. The system shows the notification itself.
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) async {}

class FirebaseMessagingService implements MessagingService {
  FirebaseMessagingService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Must be called before the app starts listening.
  static void registerBackgroundHandler() =>
      FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

  final FirebaseMessaging _messaging;
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  Future<void> Function(String token)? _onToken;
  bool _listening = false;

  PushMessage _map(RemoteMessage m) => PushMessage(
    title: m.notification?.title ?? 'Analysis done',
    body: m.notification?.body,
    analysisId: m.data['analysisId'] as String?,
  );

  @override
  Stream<PushMessage> get foreground => _foreground.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<void> start(Future<void> Function(String token) onToken) async {
    _onToken = onToken;
    // Listeners come first: getting a token can fail with no network.
    if (!_listening) {
      _listening = true;
      // ignore: deprecated_member_use
      _messaging.onTokenRefresh.listen((token) => _onToken?.call(token));
      FirebaseMessaging.onMessage.listen((m) => _foreground.add(_map(m)));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(_map(m)));
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _opened.add(_map(initial));
      await _messaging.requestPermission();
    }
    // The backend sends through the Admin SDK with registration tokens.
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    if (token != null) await onToken(token);
  }

  @override
  Future<void> deleteToken() =>
      // ignore: deprecated_member_use
      _messaging.deleteToken().timeout(const Duration(seconds: 5));
}
