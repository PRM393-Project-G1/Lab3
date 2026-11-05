import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/models/reference.dart';
import 'package:realtron/models/topic.dart';
import 'package:realtron/viewmodels/overview_view_model.dart';
import 'package:realtron/viewmodels/reference_detail_view_model.dart';
import 'package:realtron/viewmodels/reference_list_view_model.dart';
import 'package:realtron/viewmodels/topic_detail_view_model.dart';
import 'package:realtron/viewmodels/topic_map_view_model.dart';
import 'package:realtron/viewmodels/view_state.dart';

import '../fakes.dart';

void main() {
  const id = '1706.03762';

  late FakeAnalyses analyses;
  late FakeRemoteConfig remoteConfig;
  late FakeAnalytics analytics;
  late FakeDevice device;

  setUp(() {
    analyses = FakeAnalyses();
    remoteConfig = FakeRemoteConfig();
    analytics = FakeAnalytics();
    device = FakeDevice();
    analyses.analyses[id] = doneAnalysis(
      id,
      counts: const StatusCounts(hallucinated: 1, error: 1, verified: 2),
    );
    analyses.references[id] = [
      ref('v1', RefStatus.verified, index: 1, title: 'Adam'),
      ref('h1', RefStatus.hallucinated, index: 2, title: 'Ghost paper'),
      ref(
        'e1',
        RefStatus.error,
        index: 3,
        title: 'Graves',
        topicIds: const ['weak'],
      ),
      ref('v2', RefStatus.verified, index: 4, title: 'No text', topicIds: []),
    ];
    analyses.topics[id] = const [
      Topic(id: 'root', term: 'Sequence models'),
      Topic(
        id: 'weak',
        term: 'Attention',
        parentId: 'root',
        refIds: ['h1', 'e1', 'v1'],
      ),
      Topic(id: 'fine', term: 'Optimizers', parentId: 'root', refIds: ['v1']),
    ];
  });

  group('Overview', () {
    OverviewViewModel build() => OverviewViewModel(
      analyses: analyses,
      remoteConfig: remoteConfig,
      analytics: analytics,
      crashlytics: FakeCrashlytics(),
      analysisId: id,
    );

    OverviewData data(OverviewViewModel vm) =>
        (vm.state as Data<OverviewData>).value;

    test('finds weak topics and logs the view once', () async {
      final vm = build();
      await pumpEventQueue();

      expect(data(vm).topicCount, 3);
      expect(data(vm).weakTopics.map((n) => n.id), contains('weak'));
      expect(analytics.events.single, startsWith('view_analysis:4:'));

      await vm.load();
      expect(analytics.events, hasLength(1));
    });

    test('the alert shows the most severe problem', () async {
      final vm = build();
      await pumpEventQueue();
      expect(data(vm).alertStatus, RefStatus.hallucinated);

      analyses.analyses[id] = doneAnalysis(
        id,
        counts: const StatusCounts(error: 1),
      );
      await vm.load();
      expect(data(vm).alertStatus, RefStatus.error);

      analyses.analyses[id] = doneAnalysis(
        id,
        counts: const StatusCounts(verified: 3),
      );
      await vm.load();
      expect(data(vm).alertStatus, isNull);
    });

    test('a Remote Config change updates weak topics while open', () async {
      final vm = build();
      await pumpEventQueue();
      expect(data(vm).weakTopics, isNotEmpty);

      remoteConfig.change(() => remoteConfig.weakTopicMinRefs = 50);

      expect(data(vm).weakTopics, isEmpty);
    });

    test('enable_report_export hides the report action', () async {
      final vm = build();
      expect(vm.canExport, isTrue);
      remoteConfig.change(() => remoteConfig.enableReportExport = false);
      expect(vm.canExport, isFalse);
    });

    test('load errors become a retryable state', () async {
      analyses.fail = true;
      final vm = build();
      await pumpEventQueue();
      expect(vm.state, isA<Failure<OverviewData>>());

      analyses.fail = false;
      await vm.load();
      expect(vm.state, isA<Data<OverviewData>>());
    });

    test(
      'a paper with no result is a failure, not an endless spinner',
      () async {
        analyses.analyses.clear();
        final vm = build();
        await pumpEventQueue();
        expect(vm.state, isA<Failure<OverviewData>>());
      },
    );
  });

  group('Topic map', () {
    TopicMapViewModel build() => TopicMapViewModel(
      analyses: analyses,
      remoteConfig: remoteConfig,
      analytics: analytics,
      analysisId: id,
    );

    test('shows the tree, collapses a branch, counts Unclassified', () async {
      final vm = build();
      await pumpEventQueue();

      expect(vm.rows.map((r) => r.node.id), ['root', 'weak', 'fine']);
      expect(vm.unclassifiedCount, 1);
      expect(vm.unclassifiedCounts.verified, 1);

      vm.toggle('root');
      expect(vm.rows.map((r) => r.node.id), ['root']);
      expect(vm.rows.single.expanded, isFalse);

      vm.toggle('root');
      expect(vm.rows, hasLength(3));
    });

    test('Weak keeps the path down to weak topics and logs once', () async {
      final vm = build();
      await pumpEventQueue();

      vm.toggle('root');
      vm.setWeakOnly(true);
      vm.setWeakOnly(true);

      expect(
        vm.rows.map((r) => r.node.id),
        containsAllInOrder(['root', 'weak']),
      );
      expect(vm.rows.map((r) => r.node.id), isNot(contains('fine')));
      expect(
        analytics.events.where((e) => e == 'filter_weak_topics'),
        hasLength(1),
      );
    });

    test('Weak is empty when nothing is weak', () async {
      remoteConfig.weakTopicMinRefs = 50;
      final vm = build();
      await pumpEventQueue();

      vm.setWeakOnly(true);

      expect(vm.rows, isEmpty);
    });

    test('the footer percent comes from Remote Config', () async {
      final vm = build();
      expect(vm.weakPercent, 50);
      remoteConfig.change(() => remoteConfig.weakTopicThreshold = 0.35);
      expect(vm.weakPercent, 35);
    });

    test('levels below the limit open on their own screen', () async {
      analyses.topics[id] = const [
        Topic(id: 'l0', term: '0'),
        Topic(id: 'l1', term: '1', parentId: 'l0'),
        Topic(id: 'l2', term: '2', parentId: 'l1'),
        Topic(id: 'l3', term: '3', parentId: 'l2'),
        Topic(id: 'l4', term: '4', parentId: 'l3'),
      ];
      final vm = build();
      await pumpEventQueue();

      expect(vm.rows.map((r) => r.node.id), ['l0', 'l1', 'l2', 'l3']);
      expect(vm.rows.last.expanded, isNull);
    });
  });

  group('Topic detail', () {
    TopicDetailViewModel build(String topicId) => TopicDetailViewModel(
      analyses: analyses,
      remoteConfig: remoteConfig,
      analytics: analytics,
      analysisId: id,
      topicId: topicId,
    );

    test('lists references most severe first, and filters', () async {
      final vm = build('weak');
      await pumpEventQueue();

      expect(vm.visibleReferences.map((r) => r.id), ['h1', 'e1', 'v1']);
      expect(analytics.events, ['view_topic:true']);

      vm.setFilter(RefStatus.error);
      expect(vm.visibleReferences.map((r) => r.id), ['e1']);

      vm.setFilter(RefStatus.warning);
      expect(vm.visibleReferences, isEmpty);

      vm.setFilter(null);
      expect(vm.visibleReferences, hasLength(3));
    });

    test('a parent includes the references of its subtopics', () async {
      final vm = build('root');
      await pumpEventQueue();
      expect(vm.visibleReferences, hasLength(3));
    });

    test('an unknown topic is a failure', () async {
      final vm = build('gone');
      await pumpEventQueue();
      expect(vm.state, isA<Failure<TopicDetailData>>());
    });
  });

  group('Reference list', () {
    ReferenceListViewModel build({String? filter}) => ReferenceListViewModel(
      analyses: analyses,
      analysisId: id,
      filter: filter,
    );

    test('sorts by severity', () async {
      final vm = build();
      await pumpEventQueue();
      expect(vm.visible.map((r) => r.id), ['h1', 'e1', 'v1', 'v2']);
      expect(vm.totalCount, 4);
    });

    test('reads the filter from the route', () async {
      final fabricated = build(filter: 'hallucinated');
      final unclassified = build(filter: 'unclassified');
      final unknown = build(filter: 'nonsense');
      await pumpEventQueue();

      expect(fabricated.visible.map((r) => r.id), ['h1']);
      expect(unclassified.visible.map((r) => r.id), ['v2']);
      expect(unknown.filter, ReferenceFilter.all);
    });

    test('search looks in title and authors, with the filter', () async {
      analyses.references[id]!.add(
        const Reference(
          id: 'a1',
          index: 9,
          title: 'Other',
          status: RefStatus.error,
          authors: ['Vaswani'],
        ),
      );
      final vm = build();
      await pumpEventQueue();

      vm.setQuery('VASWANI');
      expect(vm.visible.map((r) => r.id), ['a1']);

      vm.setFilter(ReferenceFilter.of(RefStatus.verified));
      expect(vm.visible, isEmpty);
    });

    test('offers only filters with matches, plus the current one', () async {
      final vm = build(filter: 'warning');
      await pumpEventQueue();

      expect(vm.filters.map((f) => f.key), [
        'all',
        'hallucinated',
        'error',
        'warning',
        'verified',
        'unclassified',
      ]);
      expect(vm.countOf(ReferenceFilter.of(RefStatus.warning)), 0);
    });
  });

  group('Reference detail', () {
    ReferenceDetailViewModel build(String refId) => ReferenceDetailViewModel(
      analyses: analyses,
      device: device,
      analytics: analytics,
      analysisId: id,
      referenceId: refId,
    );

    test('the fabrication dialog opens once, only when fabricated', () async {
      final fabricated = build('h1');
      final clean = build('v1');
      expect(fabricated.takeFabricationPrompt(), isFalse);
      await pumpEventQueue();

      expect(fabricated.takeFabricationPrompt(), isTrue);
      expect(fabricated.takeFabricationPrompt(), isFalse);
      expect(clean.takeFabricationPrompt(), isFalse);
    });

    test('resolves topic names and logs the status', () async {
      final vm = build('e1');
      await pumpEventQueue();

      expect(analytics.events, ['view_reference:error']);
      expect(vm.topics.map((t) => t.term), ['Attention']);
    });

    test('copy fix puts the corrected values on the clipboard', () async {
      const reference = Reference(
        id: 'x',
        index: 1,
        title: 'T',
        status: RefStatus.error,
        issues: [
          ReferenceIssue(
            type: 'year',
            message: 'Year differs',
            cited: '2013',
            actual: '2014',
          ),
        ],
      );
      final vm = build('e1');
      await vm.copyFix(reference);
      expect(device.clipboard, 'year: 2013 -> 2014');
    });
  });
}
