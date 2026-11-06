import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/utils/server_url.dart';

void main() {
  test('normalizeServerUrl adds http:// and removes trailing slashes', () {
    expect(normalizeServerUrl(' 100.1.2.3:8000/ '), 'http://100.1.2.3:8000');
    expect(normalizeServerUrl('https://a.test//'), 'https://a.test');
    expect(normalizeServerUrl('   '), '');
  });

  test('hasServerHost needs a host name', () {
    expect(hasServerHost('http://100.1.2.3:8000'), isTrue);
    expect(hasServerHost('http://'), isFalse);
    expect(hasServerHost('http://[::1'), isFalse);
  });
}
