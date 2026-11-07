import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/knowledge_graph.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/models/topic_relation.dart';
import 'package:realtron/models/topic_tree.dart';

import '../fakes.dart';

void main() {
  TopicTree tree(List<Topic> topics) => TopicTree.build(
    topics: topics,
    references: [
      ref('a', RefStatus.verified),
      ref('b', RefStatus.error),
      ref('c', RefStatus.verified),
    ],
    weakThreshold: 0.5,
    weakMinRefs: 3,
  );

  const topics = [
    Topic(id: 'root', term: 'Sequence models'),
    Topic(
      id: 'att',
      term: 'Attention',
      parentId: 'root',
      refIds: ['a', 'b'],
      related: [
        RelatedTopic(topicId: 'opt', term: 'Optimizers'),
        RelatedTopic(topicId: 'gone', term: 'Not in this paper'),
      ],
      authors: [
        TopicAuthor(name: 'Ashish Vaswani', score: 2),
        TopicAuthor(name: 'Noam Shazeer', score: 1),
      ],
    ),
    Topic(
      id: 'opt',
      term: 'Optimizers',
      parentId: 'root',
      refIds: ['c'],
      related: [RelatedTopic(topicId: 'att', term: 'Attention')],
      authors: [TopicAuthor(name: 'Ashish Vaswani', score: 1)],
    ),
  ];

  test('has a node per topic and links each child to its parent', () {
    final graph = KnowledgeGraph.build(tree(topics));
    final topicNodes = graph.nodes.where((n) => n.kind == GraphNodeKind.topic);

    expect(
      topicNodes.map((n) => n.id),
      unorderedEquals(['root', 'att', 'opt']),
    );
    expect(graph.byId['att']!.label, 'Attention');
    expect(graph.byId['att']!.weight, 2);
    expect(graph.byId['root']!.weight, 3);
    expect(
      graph.edges
          .where((e) => e.kind == GraphEdgeKind.subtopic)
          .map((e) => (e.from, e.to)),
      unorderedEquals([('att', 'root'), ('opt', 'root')]),
    );
  });

  test('links related topics once and drops links outside the paper', () {
    final graph = KnowledgeGraph.build(tree(topics));
    final related = graph.edges.where((e) => e.kind == GraphEdgeKind.related);

    expect(related, hasLength(1));
    expect(related.single.touches('att'), isTrue);
    expect(related.single.touches('opt'), isTrue);
    expect(graph.hasRelated, isTrue);
  });

  test('adds the authors with the most topics, up to the limit', () {
    final graph = KnowledgeGraph.build(tree(topics), maxAuthors: 1);
    final authors = graph.nodes.where((n) => n.kind == GraphNodeKind.author);

    expect(authors.map((n) => n.label), ['Ashish Vaswani']);
    expect(authors.single.id, 'author:Ashish Vaswani');
    expect(authors.single.weight, 2);
    expect(
      graph.edges
          .where((e) => e.kind == GraphEdgeKind.author)
          .map((e) => (e.from, e.to)),
      unorderedEquals([
        ('author:Ashish Vaswani', 'att'),
        ('author:Ashish Vaswani', 'opt'),
      ]),
    );
    expect(graph.hasAuthors, isTrue);
  });

  test('places every node inside its size', () {
    final graph = KnowledgeGraph.build(tree(topics));

    expect(graph.positions.keys, unorderedEquals(graph.byId.keys));
    for (final p in graph.positions.values) {
      expect(p.dx, inInclusiveRange(0, graph.size.width));
      expect(p.dy, inInclusiveRange(0, graph.size.height));
    }
  });

  test('a graph without Saffron extras has no related or author links', () {
    final graph = KnowledgeGraph.build(
      tree(const [
        Topic(id: 'root', term: 'Root'),
        Topic(id: 'leaf', term: 'Leaf', parentId: 'root'),
      ]),
    );

    expect(graph.hasRelated, isFalse);
    expect(graph.hasAuthors, isFalse);
    expect(graph.edges, hasLength(1));
  });

  test('grows with the node count, within limits', () {
    expect(KnowledgeGraph.layoutSize(1).width, 320);
    expect(KnowledgeGraph.layoutSize(400).width, 640);
    final medium = KnowledgeGraph.layoutSize(36);
    expect(medium.width, 400);
    expect(medium.height, 640);
  });

  test('maps each Gemini relation to its edge kind', () {
    expect(GraphEdgeKind.of(RelationKind.isA), GraphEdgeKind.isA);
    expect(GraphEdgeKind.of(RelationKind.partOf), GraphEdgeKind.partOf);
    expect(GraphEdgeKind.of(RelationKind.sameAs), GraphEdgeKind.sameAs);
    expect(GraphEdgeKind.values.where((k) => k.isNamed), [
      GraphEdgeKind.isA,
      GraphEdgeKind.partOf,
      GraphEdgeKind.sameAs,
    ]);
  });
}
