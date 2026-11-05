import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/analysis.dart';
import 'package:realtron/services/api_client.dart';
import 'package:realtron/services/server_settings.dart';
import 'package:realtron/viewmodels/progress_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

void main() {
  const id = '1706.03762';

  late FakeAnalyses analyses;
  late FakeApi api;
  late ProgressViewModel vm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    analyses = FakeAnalyses();
    api = FakeApi();
    vm = ProgressViewModel(
      analyses: analyses,
      api: api,
      settings: ServerSettings(await SharedPreferences.getInstance()),
      analysisId: id,
    );
  });

  tearDown(() => vm.dispose());

  Future<void> send(Analysis analysis) async {
    analyses.push(analysis);
    await pumpEventQueue();
  }

  List<ProgressStepState> states() => vm.steps.map((s) => s.state).toList();

  test('has the five steps in order', () {
    expect(vm.steps.map((s) => s.label), [
      'References',
      'Verify',
      'Fabrication check',
      'Full text',
      'Topics',
    ]);
  });

  test('steps follow the backend stage', () async {
    await send(
      const Analysis(
        id: id,
        status: AnalysisStatus.processing,
        totalRefs: 41,
        progress: AnalysisProgress(
          stage: AnalysisStage.fabrication,
          percent: 44,
          processedRefs: 18,
        ),
      ),
    );

    expect(states(), [
      ProgressStepState.done,
      ProgressStepState.done,
      ProgressStepState.active,
      ProgressStepState.pending,
      ProgressStepState.pending,
    ]);
    expect(vm.refsLabel, '18/41 refs');
    expect(vm.fraction, 0.44);
  });

  test('done completes every step', () async {
    await send(const Analysis(id: id, status: AnalysisStatus.done));

    expect(vm.isDone, isTrue);
    expect(states(), everyElement(ProgressStepState.done));
    expect(vm.fraction, 1);
  });

  test('failure marks the current step and keeps the reason', () async {
    await send(
      const Analysis(
        id: id,
        status: AnalysisStatus.failed,
        error: 'PDF not found',
        progress: AnalysisProgress(stage: AnalysisStage.fullText),
      ),
    );

    expect(vm.isFailed, isTrue);
    expect(vm.failureReason, 'PDF not found');
    expect(states()[3], ProgressStepState.failed);
    expect(states()[4], ProgressStepState.pending);
  });

  test('a copy that the server has not confirmed reads as offline', () async {
    await send(
      const Analysis(
        id: id,
        status: AnalysisStatus.processing,
        fromCache: true,
      ),
    );

    expect(vm.isOffline, isTrue);
  });

  test('stop asks the backend', () async {
    expect(await vm.stop(), isTrue);
    expect(api.cancelled, [id]);
    expect(vm.commandFailed, isFalse);
  });

  test('a stop that cannot reach the backend reports it', () async {
    api.failure = ApiFailure.unreachable;

    expect(await vm.stop(), isFalse);

    expect(vm.commandFailed, isTrue);
    expect(vm.busy, isFalse);
  });

  test('retry starts the same paper again', () async {
    expect(await vm.retry(), isTrue);
    expect(api.started, [id]);
  });
}
