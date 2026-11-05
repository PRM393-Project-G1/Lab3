import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/models/topic_tree.dart';

import '../fakes.dart';

void main() {
  final references = [
    ref('a', RefStatus.hallucinated),
    ref('b', RefStatus.error),
    ref('c', RefStatus.verified),
    ref('d', RefStatus.verified),
    ref('e', RefStatus.warning),
  ];

  TopicTree build(
    List<Topic> topics, {
    double threshold = 0.5,
    int minRefs = 3,
  }) => TopicTree.build(
    topics: topics,
    references: references,
    weakThreshold: threshold,
    weakMinRefs: minRefs,
  );

  test('links children to parents and keeps orphans as roots', () {
    final tree = build(const [
      Topic(id: 'root', term: 'Root'),
      Topic(id: 'child', term: 'Child', parentId: 'root'),
      Topic(id: 'orphan', term: 'Orphan', parentId: 'gone'),
    ]);

    expect(tree.roots.map((n) => n.id), containsAll(['root', 'orphan']));
    expect(tree.byId['child']!.parent, tree.byId['root']);
    expect(tree.byId['child']!.depth, 1);
    expect(tree.byId['child']!.path.map((n) => n.id), ['root', 'child']);
  });

  test('counts a reference once when it sits in two subtopics', () {
    final tree = build(const [
      Topic(id: 'root', term: 'Root'),
      Topic(id: 'x', term: 'X', parentId: 'root', refIds: ['a', 'c']),
      Topic(id: 'y', term: 'Y', parentId: 'root', refIds: ['a', 'd']),
    ]);

    final root = tree.byId['root']!;
    expect(root.counts.total, 3);
    expect(root.counts.hallucinated, 1);
    expect(root.counts.verified, 2);
  });

  test('a topic is weak when issues reach the threshold', () {
    final tree = build(const [
      Topic(id: 'weak', term: 'Weak', refIds: ['a', 'b', 'c']),
      Topic(id: 'fine', term: 'Fine', refIds: ['a', 'c', 'd']),
    ]);

    expect(tree.byId['weak']!.isWeak, isTrue);
    expect(tree.byId['fine']!.isWeak, isFalse);
    expect(tree.weak.map((n) => n.id), ['weak']);
  });

  test('warnings do not make a topic weak', () {
    final tree = build(const [
      Topic(id: 't', term: 'T', refIds: ['c', 'e', 'd']),
    ]);

    expect(tree.byId['t']!.counts.warning, 1);
    expect(tree.byId['t']!.isWeak, isFalse);
  });

  test('topics below the minimum size are never weak', () {
    final tree = build(const [
      Topic(id: 'small', term: 'Small', refIds: ['a', 'b']),
    ]);

    expect(tree.byId['small']!.isWeak, isFalse);
  });

  test('the Remote Config threshold changes the result', () {
    const topics = [
      Topic(id: 't', term: 'T', refIds: ['a', 'c', 'd']),
    ];

    expect(build(topics, threshold: 0.5).byId['t']!.isWeak, isFalse);
    expect(build(topics, threshold: 0.3).byId['t']!.isWeak, isTrue);
  });

  test('marks a parent that only has a weak topic further down', () {
    final tree = build(const [
      Topic(id: 'root', term: 'Root', refIds: ['c', 'd', 'e']),
      Topic(id: 'child', term: 'Child', parentId: 'root'),
      Topic(
        id: 'leaf',
        term: 'Leaf',
        parentId: 'child',
        refIds: ['a', 'b', 'c'],
      ),
    ], threshold: 0.6);

    expect(tree.byId['root']!.isWeak, isFalse);
    expect(tree.byId['root']!.hasWeakBelow, isTrue);
  });

  test('falls back to stored counts when references are missing', () {
    final tree = TopicTree.build(
      topics: const [
        Topic(
          id: 't',
          term: 'T',
          counts: StatusCounts(hallucinated: 2, verified: 1),
        ),
      ],
      references: const [],
      weakThreshold: 0.5,
      weakMinRefs: 3,
    );

    expect(tree.byId['t']!.counts.total, 3);
    expect(tree.byId['t']!.isWeak, isTrue);
  });
}
