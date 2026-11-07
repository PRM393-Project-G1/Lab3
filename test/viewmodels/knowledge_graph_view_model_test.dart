import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/firebase/ai_service.dart';
import 'package:realtron/models/knowledge_graph.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/models/topic_relation.dart';
import 'package:realtron/viewmodels/knowledge_graph_view_model.dart';
import 'package:realtron/viewmodels/view_state.dart';

import '../fakes.dart';

void main() {
  const id = '1706.03762';

  late FakeAnalyses analyses;
  late FakeRemoteConfig remoteConfig;
  late FakeAi ai;
  late FakeCrashlytics crashlytics;

  setUp(() {
    analyses = FakeAnalyses()
      ..analyses[id] = doneAnalysis(id)
      ..references[id] = [
        ref('a', RefStatus.verified),
        ref('b', RefStatus.error),
        ref('c', RefStatus.hallucinated),
      ]
      ..topics[id] = const [
        Topic(id: 'root', term: 'Sequence models'),
        Topic(
          id: 'att',
          term: 'Attention',
          parentId: 'root',
          refIds: ['a', 'b'],
          related: [RelatedTopic(topicId: 'opt', term: 'Optimizers')],
          authors: [TopicAuthor(name: 'Ashish Vaswani')],
        ),
        Topic(
          id: 'self',
          term: 'Self-attention',
          parentId: 'att',
          refIds: ['c'],
        ),
        Topic(id: 'opt', term: 'Optimizers', parentId: 'root', refIds: ['a']),
      ];
    remoteConfig = FakeRemoteConfig()..geminiModel = 'gemini-from-rc';
    ai = FakeAi();
    crashlytics = FakeCrashlytics();
  });

  Future<KnowledgeGraphViewModel> build() async {
    final vm = KnowledgeGraphViewModel(
      analyses: analyses,
      remoteConfig: remoteConfig,
      ai: ai,
      crashlytics: crashlytics,
      analysisId: id,
    );
    await pumpEventQueue();
    return vm;
  }

  test('shows the graph, then the relations Gemini names', () async {
    ai.relations = const [
      TopicRelation('self-attention', 'Attention', RelationKind.isA),
      TopicRelation('Attention', 'Recurrence', RelationKind.partOf),
    ];
    final vm = await build();

    expect(vm.state, isA<Data<KnowledgeGraph>>());
    expect(vm.paperTitle, 'Attention Is All You Need');
    expect(vm.relationsStatus, RelationsStatus.ready);
    // Terms go back to topic ids; one that is not a topic is dropped.
    expect(vm.relations, const [
      TopicRelation('self', 'att', RelationKind.isA),
    ]);
    expect(
      vm.visibleEdges.where((e) => e.kind == GraphEdgeKind.isA).single.from,
      'self',
    );

    final call = ai.calls.single;
    expect(call.model, 'gemini-from-rc');
    expect(call.paperTitle, 'Attention Is All You Need');
    // Largest topics first, then the higher ones in the tree.
    expect(call.terms, [
      'Sequence models',
      'Attention',
      'Optimizers',
      'Self-attention',
    ]);
  });

  test('shows the graph while Gemini is still answering', () async {
    ai.gate = Completer();
    final vm = await build();

    expect(vm.state, isA<Data<KnowledgeGraph>>());
    expect(vm.relationsStatus, RelationsStatus.loading);

    ai.gate!.complete();
    await pumpEventQueue();
    expect(vm.relationsStatus, RelationsStatus.ready);
  });

  test(
    'a Gemini failure keeps the graph, is recorded and can be retried',
    () async {
      ai.error = StateError('quota');
      final vm = await build();

      expect(vm.state, isA<Data<KnowledgeGraph>>());
      expect(vm.relationsStatus, RelationsStatus.failed);
      expect(vm.failure, AiFailure.other);
      expect(crashlytics.recorded, ['gemini_relations']);

      ai.error = const AiException(AiFailure.busy);
      await vm.labelRelations();
      expect(vm.failure, AiFailure.busy);

      ai
        ..error = null
        ..relations = const [
          TopicRelation('Attention', 'Self-attention', RelationKind.sameAs),
        ];
      await vm.labelRelations();
      expect(vm.relationsStatus, RelationsStatus.ready);
      expect(vm.failure, isNull);
      expect(vm.relations, hasLength(1));
    },
  );

  test('does not ask Gemini about a single topic', () async {
    analyses.topics[id] = const [Topic(id: 'only', term: 'Only')];
    final vm = await build();

    expect(vm.relationsStatus, RelationsStatus.ready);
    expect(ai.calls, isEmpty);
  });

  test('sends each spelling once and at most maxTerms topics', () async {
    analyses.topics[id] = [
      const Topic(id: 'x', term: 'Attention'),
      const Topic(id: 'y', term: 'attention '),
      for (var i = 0; i < 80; i++) Topic(id: 't$i', term: 'Topic $i'),
    ];
    await build();

    final terms = ai.calls.single.terms;
    expect(terms, hasLength(KnowledgeGraphViewModel.maxTerms));
    expect(
      terms.where((t) => t.trim().toLowerCase() == 'attention'),
      hasLength(1),
    );
  });

  test('no topics is empty and a load error is a failure', () async {
    analyses.topics[id] = const [];
    expect((await build()).state, isA<Empty<KnowledgeGraph>>());

    analyses.fail = true;
    final failed = await build();
    expect(failed.state, isA<Failure<KnowledgeGraph>>());
    expect(ai.calls, isEmpty);
  });

  group('filters and selection', () {
    test('authors are hidden until turned on', () async {
      final vm = await build();
      bool hasAuthor() =>
          vm.visibleNodes.any((n) => n.kind == GraphNodeKind.author);

      expect(hasAuthor(), isFalse);
      expect(
        vm.visibleEdges.any((e) => e.kind == GraphEdgeKind.author),
        isFalse,
      );

      vm.setShowAuthors(true);
      expect(hasAuthor(), isTrue);
      expect(
        vm.visibleEdges.any((e) => e.kind == GraphEdgeKind.author),
        isTrue,
      );
    });

    test('related links can be hidden', () async {
      final vm = await build();
      expect(
        vm.visibleEdges.any((e) => e.kind == GraphEdgeKind.related),
        isTrue,
      );

      vm.setShowRelated(false);
      expect(
        vm.visibleEdges.any((e) => e.kind == GraphEdgeKind.related),
        isFalse,
      );
    });

    test('selecting highlights the node and its neighbours', () async {
      final vm = await build();
      expect(vm.highlighted, isEmpty);

      vm.select('self');
      expect(vm.selectedId, 'self');
      expect(vm.highlighted, {'self', 'att'});

      vm.select('unknown');
      expect(vm.selectedId, isNull);
      expect(vm.highlighted, isEmpty);
    });

    test('selecting an author shows authors; hiding them clears it', () async {
      final vm = await build();

      vm.select('author:Ashish Vaswani');
      expect(vm.showAuthors, isTrue);
      expect(vm.highlighted, {'author:Ashish Vaswani', 'att'});

      vm.setShowAuthors(false);
      expect(vm.selectedId, isNull);
    });
  });

  test('details list every link of a node, whatever the filters', () async {
    ai.relations = const [
      TopicRelation('Self-attention', 'Attention', RelationKind.isA),
    ];
    final vm = await build();
    vm.setShowRelated(false);

    final att = vm.details('att')!;
    expect(att.node.label, 'Attention');
    expect(att.parent?.id, 'root');
    expect(att.subtopics.map((n) => n.id), ['self']);
    expect(att.narrower.map((n) => n.id), ['self']);
    expect(att.broader, isEmpty);
    expect(att.related.map((n) => n.id), ['opt']);
    expect(att.authors.map((n) => n.label), ['Ashish Vaswani']);

    final self = vm.details('self')!;
    expect(self.broader.map((n) => n.id), ['att']);

    final author = vm.details('author:Ashish Vaswani')!;
    expect(author.topics.map((n) => n.id), ['att']);
    expect(vm.details('unknown'), isNull);
  });
}
