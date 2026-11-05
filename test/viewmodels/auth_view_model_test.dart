import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/app_user.dart';
import 'package:realtron/viewmodels/auth_view_model.dart';

import '../fakes.dart';

void main() {
  late FakeAuth auth;
  late FakeFirestore firestore;
  late FakeMessaging messaging;
  late FakeCrashlytics crashlytics;

  AuthViewModel build() => AuthViewModel(
    auth: auth,
    analytics: FakeAnalytics(),
    crashlytics: crashlytics,
    firestore: firestore,
    messaging: messaging,
  )..start();

  setUp(() {
    auth = FakeAuth(currentUser: null);
    firestore = FakeFirestore();
    messaging = FakeMessaging();
    crashlytics = FakeCrashlytics();
  });

  test('each account that signs in registers the device token', () async {
    build();

    auth.change(const AppUser(uid: 'a'));
    await pumpEventQueue();
    auth.change(null);
    await pumpEventQueue();
    auth.change(const AppUser(uid: 'b'));
    await pumpEventQueue();

    expect(firestore.fcmTokens, ['a:t1', 'b:t1']);
  });

  test(
    'a user document that waits for the network does not stop pushes',
    () async {
      firestore.hangEnsureUser = true;
      build();

      auth.change(const AppUser(uid: 'a'));
      await pumpEventQueue();

      expect(messaging.starts, 1);
      expect(firestore.fcmTokens, isEmpty);
    },
  );

  test('a failed user document is logged and pushes still start', () async {
    firestore.failEnsureUser = true;
    build();

    auth.change(const AppUser(uid: 'a'));
    await pumpEventQueue();

    expect(messaging.starts, 1);
    expect(crashlytics.recorded, contains('sync_user'));
  });
}
