import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/app_routes.dart';

void main() {
  test('a tapped push opens its paper, else the inbox for admin messages', () {
    expect(
      AppRoutes.forPush(adminMessage: true, analysisId: '1706.03762'),
      '/analyses/1706.03762',
    );
    expect(AppRoutes.forPush(adminMessage: true), '/notifications');
    expect(
      AppRoutes.forPush(adminMessage: false, analysisId: '1706.03762'),
      '/analyses/1706.03762',
    );
    expect(AppRoutes.forPush(adminMessage: false, analysisId: ''), isNull);
  });
}
