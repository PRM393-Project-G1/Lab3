import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realtron/models/ref_status.dart';
import 'package:realtron/theme/app_theme.dart';
import 'package:realtron/widgets/analysis_stepper.dart';
import 'package:realtron/widgets/app_bottom_nav.dart';
import 'package:realtron/widgets/app_button.dart';
import 'package:realtron/widgets/app_card.dart';
import 'package:realtron/widgets/app_dialog.dart';
import 'package:realtron/widgets/app_filter_chip.dart';
import 'package:realtron/widgets/app_text_field.dart';
import 'package:realtron/widgets/app_top_bar.dart';
import 'package:realtron/widgets/cited_actual_table.dart';
import 'package:realtron/widgets/export_sheet.dart';
import 'package:realtron/widgets/history_card.dart';
import 'package:realtron/widgets/info_banner.dart';
import 'package:realtron/widgets/notification_tile.dart';
import 'package:realtron/widgets/reference_card.dart';
import 'package:realtron/widgets/remote_config_row.dart';
import 'package:realtron/widgets/section_label.dart';
import 'package:realtron/widgets/skeleton_list.dart';
import 'package:realtron/widgets/state_view.dart';
import 'package:realtron/widgets/status_bar.dart';
import 'package:realtron/widgets/status_chip.dart';
import 'package:realtron/widgets/topic_tree_node.dart';
import 'package:realtron/widgets/weak_tag.dart';

const _counts = StatusCounts(
  hallucinated: 2,
  error: 3,
  warning: 4,
  unverified: 3,
  verified: 29,
);

/// Every design-system component with long sample text, as one scrolling page.
Widget _gallery() => MaterialApp(
  theme: buildAppTheme(useGoogleFonts: false),
  home: Scaffold(
    appBar: const AppTopBar(
      title: 'Paper Overview',
      subtitle: 'Attention Is All You Need',
    ),
    bottomNavigationBar: AppBottomNav(selectedIndex: 0, onSelected: (_) {}),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppButton('Analyze', onPressed: () {}, expand: true),
        AppButton(
          'Test',
          onPressed: () {},
          variant: AppButtonVariant.secondary,
        ),
        AppButton('Save', onPressed: () {}, variant: AppButtonVariant.text),
        AppButton(
          'Crash',
          onPressed: () {},
          variant: AppButtonVariant.destructive,
        ),
        AppButton('Testing…', onPressed: () {}, loading: true),
        AppTextField(
          label: 'arXiv ID or link',
          helper: 'e.g. 1706.03762',
          onPaste: () {},
        ),
        const AppTextField(
          label: 'Server URL',
          errorText: 'Not a valid arXiv ID',
        ),
        const AppCard(child: Text('Card')),
        const SectionLabel('Recent'),
        for (final status in RefStatus.values) StatusChip(status, count: 12),
        StatusChip(RefStatus.error, onTap: () {}),
        const WeakTag(),
        Wrap(
          children: [
            AppFilterChip(
              label: 'All',
              count: 41,
              selected: true,
              onSelected: (_) {},
            ),
            AppFilterChip(
              label: 'Hallucinated',
              count: 2,
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
        const StatusBar(_counts, showLegend: true),
        ReferenceCard(
          status: RefStatus.hallucinated,
          title: 'Generating sequences with recurrent neural networks',
          byline: 'Graves · 2013',
          issue: 'No matching paper found in 5 databases',
          onTap: () {},
        ),
        HistoryCard(
          title: 'Attention Is All You Need',
          arxivId: '1706.03762',
          timeLabel: '2 h ago',
          counts: _counts,
          onTap: () {},
          onRename: () {},
          onDelete: () {},
        ),
        const HistoryCard(
          title: 'FlashAttention: Fast and Memory-Efficient Exact Attention',
          arxivId: '2205.14135',
          timeLabel: '4 h ago',
          state: HistoryCardState.running,
        ),
        const HistoryCard(
          title: 'Neural Machine Translation by Jointly Learning to Align and Translate',
          arxivId: '1409.0473',
          timeLabel: '1 d ago',
          state: HistoryCardState.removed,
        ),
        TopicTreeNode(
          name: 'Attention mechanisms in neural machine translation',
          counts: _counts,
          depth: 2,
          isWeak: true,
          expanded: false,
          onToggle: () {},
          onTap: () {},
        ),
        const TopicTreeNode(
          name: 'Unclassified',
          counts: StatusCounts(unverified: 3),
          note: 'No readable text',
        ),
        const AnalysisStepper(
          steps: [
            AnalysisStep('References', AnalysisStepStatus.done),
            AnalysisStep('Verify', AnalysisStepStatus.failed),
            AnalysisStep('Fabrication check', AnalysisStepStatus.active),
            AnalysisStep('Full text', AnalysisStepStatus.pending),
          ],
        ),
        NotificationTile(
          title: 'Analysis done',
          body: 'Attention Is All You Need · 2 flagged',
          timeLabel: '5 min ago',
          unread: true,
          onTap: () {},
        ),
        const RemoteConfigRow(keyName: 'weak_topic_threshold', value: '0.5'),
        const CitedActualTable(
          rows: [
            CitedActualRow(field: 'Year', cited: '2016', actual: '2017'),
            CitedActualRow(
              field: 'Title',
              cited: 'Layer Normalization',
              actual: 'Layer Normalization',
            ),
          ],
        ),
        InfoBanner(
          tone: BannerTone.error,
          title: "Can't reach server",
          message: 'Check Tailscale and backend.',
          actions: [
            AppButton(
              'Retry',
              onPressed: () {},
              variant: AppButtonVariant.secondary,
            ),
            AppButton(
              'Change server',
              onPressed: () {},
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
        for (final tone in BannerTone.values)
          InfoBanner(tone: tone, title: 'Offline · will resume'),
        for (final stage in ExportStage.values)
          ExportSheet(
            stage: stage,
            progress: 0.64,
            fileLabel: 'realtron_1706.03762.pdf · 214 KB',
            onCopyLink: () {},
            onOpen: () {},
            onShare: () {},
            onRetry: () {},
          ),
        SizedBox(
          height: 320,
          child: StateView.empty(
            icon: Icons.search_off_rounded,
            title: 'No weak topics',
            actionLabel: 'Show all',
            onAction: () {},
          ),
        ),
        SizedBox(height: 320, child: StateView.error(onAction: () {})),
        const SizedBox(
          height: 360,
          child: StateView.empty(
            icon: Icons.visibility_off_rounded,
            title: 'Results unavailable',
            message: 'An administrator removed these results: references were parsed from the wrong PDF version',
          ),
        ),
        const SizedBox(height: 300, child: SkeletonList(itemCount: 2)),
        AppDialog(
          title: 'Stop analysis?',
          message: 'Progress will be lost.',
          confirmLabel: 'Stop',
          cancelLabel: 'Keep going',
          destructive: true,
          onConfirm: () {},
          onCancel: () {},
        ),
      ],
    ),
  ),
);

Future<void> _pumpGallery(
  WidgetTester tester,
  double width,
  double scale,
) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(_gallery());
  final context = tester.element(find.byType(Scaffold));
  expect(MediaQuery.textScalerOf(context).scale(10), closeTo(10 * scale, 0.01));
  expect(MediaQuery.sizeOf(context).width, width);
}

void main() {
  for (final width in [360.0, 412.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at $width dp, text scale $scale', (
        tester,
      ) async {
        await _pumpGallery(tester, width, scale);
        final list = find.byType(Scrollable).first;
        // Scroll through the whole page so every component gets laid out.
        for (var i = 0; i < 60; i++) {
          await tester.drag(list, const Offset(0, -500));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('touch targets and contrast meet the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpGallery(tester, 360, 1.0);
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 30; i++) {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
    }
    handle.dispose();
  });

  test('StatusCounts adds up', () {
    expect(_counts.total, 41);
    expect(_counts.of(RefStatus.hallucinated), 2);
  });
}
