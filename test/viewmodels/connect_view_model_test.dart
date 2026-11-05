import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:realtron/viewmodels/connect_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  late FakeApi api;
  late ServerSettings settings;
  late FakeCrashlytics crashlytics;

  ConnectViewModel build() => ConnectViewModel(
    api: api,
    settings: settings,
    device: FakeDevice(),
    crashlytics: crashlytics,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi();
    settings = ServerSettings(await SharedPreferences.getInstance());
    crashlytics = FakeCrashlytics();
  });

  test('normalize adds http:// and removes trailing slashes', () {
    expect(
      ConnectViewModel.normalize(' 100.1.2.3:8000/ '),
      'http://100.1.2.3:8000',
    );
    expect(ConnectViewModel.normalize('https://a.test//'), 'https://a.test');
    expect(ConnectViewModel.normalize('   '), '');
  });

  test('an empty address never reaches the network', () async {
    final vm = build();
    await vm.test();
    expect(vm.status, ConnectStatus.empty);
    expect(vm.canSave, isFalse);
  });

  test('a successful test unlocks saving, with the latency', () async {
    final vm = build()..setUrl('100.1.2.3:8000');
    expect(vm.canSave, isFalse);

    await vm.test();

    expect(vm.status, ConnectStatus.connected);
    expect(vm.latencyMs, 84);
    expect(vm.canSave, isTrue);

    await vm.save();
    expect(settings.serverUrl, 'http://100.1.2.3:8000');
  });

  for (final failure in const [
    ApiFailure.unreachable,
    ApiFailure.timeout,
    ApiFailure.notRealtron,
  ]) {
    test('keeps the exact cause: $failure', () async {
      api.failure = failure;
      final vm = build()..setUrl('100.1.2.3:8000');

      await vm.test();

      expect(vm.status, ConnectStatus.failed);
      expect(vm.failure, failure);
      expect(vm.canSave, isFalse);
      expect(crashlytics.keys['server_reachable'], false);
    });
  }

  test('saving does nothing before a successful test', () async {
    api.failure = ApiFailure.unreachable;
    final vm = build()..setUrl('100.1.2.3:8000');
    await vm.test();
    await vm.save();
    expect(settings.serverUrl, isNull);
  });

  test('editing the address clears the previous result', () async {
    final vm = build()..setUrl('100.1.2.3:8000');
    await vm.test();

    vm.setUrl('100.1.2.3:9000');

    expect(vm.status, ConnectStatus.idle);
    expect(vm.latencyMs, isNull);
    expect(vm.canSave, isFalse);
  });
}
