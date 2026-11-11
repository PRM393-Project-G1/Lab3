import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/analysis.dart';

void main() {
  test(
    'hidden results carry their reason; a stale reason alone hides nothing',
    () {
      final hidden = Analysis.fromMap('1706.03762', {
        'status': 'done',
        'hidden': true,
        'hiddenReason': 'Parsed from the wrong PDF',
      });
      expect(hidden.hidden, isTrue);
      expect(hidden.hiddenReason, 'Parsed from the wrong PDF');

      final visible = Analysis.fromMap('1706.03762', {
        'status': 'done',
        'hidden': false,
        'hiddenReason': 'Old reason',
      });
      expect(visible.hidden, isFalse);
      expect(visible.hiddenReason, isNull);
      expect(
        Analysis.fromMap('1706.03762', {'status': 'done'}).hidden,
        isFalse,
      );
    },
  );
}
