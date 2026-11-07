import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/topic.dart';

void main() {
  test("reads Saffron's extra fields", () {
    final topic = Topic.fromMap('t-attention', {
      'term': 'attention',
      'importance': 1.18,
      'occurrences': 31,
      'related': [
        {'topicId': 't-translation', 'term': 'translation', 'similarity': 0.4},
      ],
      'authors': [
        {'name': 'Ashish Vaswani', 'score': 18.6},
      ],
    });

    expect(topic.importance, 1.18);
    expect(topic.occurrences, 31);
    expect(topic.mentions, '31 mentions');
    expect(topic.related.single.topicId, 't-translation');
    expect(topic.related.single.term, 'translation');
    expect(topic.related.single.similarity, 0.4);
    expect(topic.authors.single.name, 'Ashish Vaswani');
  });

  test('an older analysis without them still loads', () {
    final topic = Topic.fromMap('t', {'term': 'T'});

    expect(topic.importance, 0);
    expect(topic.mentions, isNull);
    expect(topic.related, isEmpty);
    expect(topic.authors, isEmpty);
  });

  test('skips entries it cannot use', () {
    final topic = Topic.fromMap('t', {
      'related': [
        'not a map',
        {'term': 'no id'},
        {'topicId': 'ok'},
      ],
      'authors': [
        {'name': '  '},
        {'score': 1},
        {'name': 'Kept'},
      ],
      'occurrences': 1,
    });

    expect(topic.related.map((r) => (r.topicId, r.term)), [('ok', 'ok')]);
    expect(topic.authors.map((a) => a.name), ['Kept']);
    expect(topic.mentions, '1 mention');
  });

  test('a wrong type for a list is treated as missing', () {
    final topic = Topic.fromMap('t', {'related': 'x', 'authors': 3});
    expect(topic.related, isEmpty);
    expect(topic.authors, isEmpty);
  });
}
