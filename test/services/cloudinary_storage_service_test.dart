import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/cloudinary_storage_service.dart';

import '../fakes.dart';

void main() {
  const fileName = 'realtron_1706.03762.pdf';
  final bytes = Uint8List.fromList(List.filled(2048, 7));

  CloudinaryStorageService service(MockClientHandler handler, {FakeApi? api}) =>
      CloudinaryStorageService(
        api: api ?? FakeApi(),
        client: MockClient(handler),
      );

  test('sends the signed fields and the file, and returns the link', () async {
    late http.Request sent;
    final progress = <double>[];
    final uploaded = await service((request) async {
      sent = request;
      return http.Response(
        jsonEncode({
          'public_id': 'reports/user-1/$fileName',
          'secure_url': 'https://res.test/raw/upload/reports/user-1/$fileName',
        }),
        200,
      );
    }).uploadReport(
      uid: 'user-1',
      fileName: fileName,
      bytes: bytes,
      onProgress: progress.add,
    );

    expect(sent.url.toString(), 'https://upload.test/raw/upload');
    expect(sent.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(sent.bodyBytes);
    for (final field in ['api_key', 'public_id', 'timestamp', 'signature']) {
      expect(body, contains('name="$field"'));
    }
    expect(body, contains('reports/user-1/$fileName'));
    expect(body, contains('filename="$fileName"'));
    expect(uploaded.path, 'reports/user-1/$fileName');
    expect(uploaded.url, 'https://res.test/raw/upload/reports/user-1/$fileName');
    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });

  test('a refused upload is an error, not a link', () {
    final upload = service(
      (_) async => http.Response('{"error":{"message":"Invalid Signature"}}', 401),
    ).uploadReport(
      uid: 'user-1',
      fileName: fileName,
      bytes: bytes,
      onProgress: (_) {},
    );

    expect(upload, throwsA(isA<http.ClientException>()));
  });

  test('without a signature nothing is sent to Cloudinary', () async {
    var calls = 0;
    final api = FakeApi()..failure = ApiFailure.unreachable;
    final upload = service((_) async {
      calls++;
      return http.Response('{}', 200);
    }, api: api).uploadReport(
      uid: 'user-1',
      fileName: fileName,
      bytes: bytes,
      onProgress: (_) {},
    );

    await expectLater(upload, throwsA(isA<ApiException>()));
    expect(calls, 0);
  });
}
