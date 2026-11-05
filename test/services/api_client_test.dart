import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  const base = 'http://100.1.2.3:8000';

  late ServerSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': base});
    settings = ServerSettings(await SharedPreferences.getInstance());
  });

  HttpApiClient client(MockClientHandler handler) => HttpApiClient(
    settings: settings,
    auth: FakeAuth(),
    client: MockClient(handler),
  );

  Matcher failsWith(ApiFailure failure) =>
      throwsA(isA<ApiException>().having((e) => e.failure, 'failure', failure));

  group('health', () {
    test('accepts a Realtron server', () async {
      final api = client((request) async {
        expect(request.url.toString(), '$base/api/health');
        return http.Response(jsonEncode({'status': 'ok', 'version': '1'}), 200);
      });

      expect(await api.health(base), greaterThanOrEqualTo(0));
    });

    test('another server answering 404 is not Realtron', () {
      final api = client((_) async => http.Response('nope', 404));
      expect(api.health(base), failsWith(ApiFailure.notRealtron));
    });

    test('a page that is not JSON is not Realtron', () {
      final api = client((_) async => http.Response('<html></html>', 200));
      expect(api.health(base), failsWith(ApiFailure.notRealtron));
    });

    test('JSON of another shape is not Realtron', () {
      final api = client((_) async => http.Response('[1, 2]', 200));
      expect(api.health(base), failsWith(ApiFailure.notRealtron));
    });

    test('no route to the host is unreachable', () {
      final api = client((_) => throw const SocketException('no route'));
      expect(api.health(base), failsWith(ApiFailure.unreachable));
    });
  });

  group('commands', () {
    test('start sends the ID, the switch and the Firebase token', () async {
      late http.Request sent;
      final api = client((request) async {
        sent = request;
        return http.Response('{"analysisId":"1","status":"queued"}', 202);
      });

      await api.startAnalysis('1706.03762', aiAssisted: false);

      expect(sent.url.toString(), '$base/api/analyses');
      expect(sent.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(sent.body), {
        'arxivId': '1706.03762',
        'aiAssisted': false,
      });
    });

    test('cancel posts to the analysis', () async {
      late http.Request sent;
      final api = client((request) async {
        sent = request;
        return http.Response('{}', 200);
      });

      await api.cancelAnalysis('1706.03762');

      expect(sent.url.toString(), '$base/api/analyses/1706.03762/cancel');
    });

    test('a refused command is reported as rejected', () {
      final api = client((_) async => http.Response('denied', 401));
      expect(
        api.startAnalysis('1706.03762', aiAssisted: true),
        failsWith(ApiFailure.rejected),
      );
    });

    test('no saved server is reported before any request', () async {
      await settings.clear();
      final api = client((_) async => fail('should not send'));
      expect(api.cancelAnalysis('1'), failsWith(ApiFailure.noServer));
    });
  });
}
