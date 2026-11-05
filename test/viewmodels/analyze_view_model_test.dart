import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/models/library_entry.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/library_feed.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:realtron/viewmodels/analyze_view_model.dart';
import 'package:realtron/viewmodels/view_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  const id = '1706.03762';

  late FakeApi api;
  late FakeAnalyses analyses;
  late FakeLibrary library;
  late FakeAnalytics analytics;
  late FakeRemoteConfig remoteConfig;
  late FakeDevice device;
  late ServerSettings settings;

  AnalyzeViewModel build({String? sharedText}) => AnalyzeViewModel(
    api: api,
    analyses: analyses,
    library: library,
    feed: LibraryFeed(library, analyses),
    auth: FakeAuth(),
    settings: settings,
    remoteConfig: remoteConfig,
    analytics: analytics,
    crashlytics: FakeCrashlytics(),
    device: device,
    sharedText: sharedText,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi();
    analyses = FakeAnalyses();
    library = FakeLibrary();
    analytics = FakeAnalytics();
    remoteConfig = FakeRemoteConfig();
    device = FakeDevice();
    settings = ServerSettings(await SharedPreferences.getInstance());
  });

  test('checks the format on the device', () {
    final vm = build();
    expect(vm.canSubmit, isFalse);
    expect(vm.showInvalid, isFalse);

    vm.setInput('not an id');
    expect(vm.showInvalid, isTrue);
    expect(vm.canSubmit, isFalse);

    vm.setInput(id);
    expect(vm.showInvalid, isFalse);
    expect(vm.canSubmit, isTrue);
  });

  test('a shared link arrives already filled in', () {
    final vm = build(sharedText: 'https://arxiv.org/abs/$id');
    expect(vm.input, 'https://arxiv.org/abs/$id');
    expect(vm.canSubmit, isTrue);
  });

  test('an invalid ID sends nothing', () async {
    final vm = build()..setInput('nope');
    expect(await vm.submit(), isNull);
    expect(api.started, isEmpty);
  });

  test('a finished result opens directly, with no backend call', () async {
    analyses.analyses[id] = doneAnalysis(id);
    final vm = build()..setInput(id);

    final target = await vm.submit();

    expect(target?.ready, isTrue);
    expect(api.started, isEmpty);
    expect(library.touched, [id]);
    expect(analytics.events, contains('search:true'));
  });

  test('a new paper starts an analysis', () async {
    final vm = build()..setInput('https://arxiv.org/pdf/$id');

    final target = await vm.submit();

    expect(target?.arxivId, id);
    expect(target?.ready, isFalse);
    expect(api.started, [id]);
    expect(library.touched, [id]);
    expect(analytics.events, contains('search:false'));
  });

  test('a running analysis is joined, not started twice', () async {
    analyses.analyses[id] = const Analysis(
      id: id,
      status: AnalysisStatus.processing,
    );
    final vm = build()..setInput(id);

    final target = await vm.submit();

    expect(target?.ready, isFalse);
    expect(api.started, isEmpty);
  });

  test('a failed result can be analyzed again', () async {
    analyses.analyses[id] = const Analysis(
      id: id,
      status: AnalysisStatus.failed,
    );
    final vm = build()..setInput(id);

    await vm.submit();

    expect(api.started, [id]);
  });

  for (final failure in const [ApiFailure.unreachable, ApiFailure.timeout]) {
    test('$failure shows the server problem and saves nothing', () async {
      api.failure = failure;
      final vm = build()..setInput(id);

      expect(await vm.submit(), isNull);

      expect(vm.problem, AnalyzeProblem.unreachable);
      expect(vm.submitting, isFalse);
      expect(library.touched, isEmpty);
    });
  }

  test('typing again clears the problem', () async {
    api.failure = ApiFailure.unreachable;
    final vm = build()..setInput(id);
    await vm.submit();

    vm.setInput('1706.0376');

    expect(vm.problem, isNull);
  });

  test('recent checks follow max_recent_checks', () async {
    library.entries = [
      for (var i = 0; i < 5; i++)
        LibraryEntry(arxivId: '2001.0000$i', addedAt: DateTime(2026, 1, i + 1)),
    ];
    final vm = build();
    await pumpEventQueue();

    expect((vm.recent as Data<List<LibraryEntry>>).value, hasLength(5));

    remoteConfig.change(() => remoteConfig.maxRecentChecks = 2);

    expect((vm.recent as Data<List<LibraryEntry>>).value, hasLength(2));
  });

  test('no history gives the first-use state', () async {
    final vm = build();
    await pumpEventQueue();
    expect(vm.recent, isA<Empty<List<LibraryEntry>>>());
  });

  test('the AI check switch is remembered', () async {
    final vm = build();
    expect(vm.aiCheck, isTrue);

    await vm.setAiCheck(false);

    expect(vm.aiCheck, isFalse);
    expect(settings.aiCheck, isFalse);
  });
}
