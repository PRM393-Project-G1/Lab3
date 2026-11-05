import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/utils/arxiv_id.dart';

void main() {
  group('parseArxivId', () {
    for (final input in const [
      '1706.03762',
      ' 1706.03762 ',
      'arXiv:1706.03762',
      '1706.03762v5',
      'https://arxiv.org/abs/1706.03762',
      'https://arxiv.org/abs/1706.03762v7',
      'https://arxiv.org/pdf/1706.03762.pdf',
      'https://arxiv.org/pdf/1706.03762',
      'arxiv.org/abs/1706.03762',
    ]) {
      test('accepts "$input"', () {
        expect(parseArxivId(input), '1706.03762');
      });
    }

    for (final input in const [
      '',
      '   ',
      'attention',
      '17.03762',
      '1706.0',
      'https://example.com/abs/1706.03762',
    ]) {
      test('rejects "$input"', () {
        expect(parseArxivId(input), isNull);
      });
    }
  });
}
