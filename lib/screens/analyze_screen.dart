import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/analyze_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/info_banner.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton_list.dart';
import 'library_entry_card.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: context.read<AnalyzeViewModel>().input,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(AnalyzeViewModel vm) async {
    final target = await vm.submit();
    if (target == null || !mounted) return;
    context.push(
      target.ready
          ? '/analyses/${target.arxivId}'
          : '/analyses/${target.arxivId}/progress',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyzeViewModel>();
    return Scaffold(
      appBar: AppTopBar(
        title: 'Analyze',
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'arXiv ID or link',
                  helper: 'e.g. ${AnalyzeViewModel.example}',
                  controller: _input,
                  errorText: vm.showInvalid ? 'Not a valid arXiv ID' : null,
                  textInputAction: TextInputAction.go,
                  onChanged: vm.setInput,
                  onSubmitted: (_) => _submit(vm),
                  onPaste: () async {
                    final text = await vm.paste();
                    if (text != null) _input.text = text;
                  },
                ),
                if (vm.input.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ActionChip(
                    label: const Text('Try ${AnalyzeViewModel.example}'),
                    onPressed: () {
                      _input.text = AnalyzeViewModel.example;
                      vm.setInput(AnalyzeViewModel.example);
                    },
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AI check'),
                  value: vm.aiCheck,
                  onChanged: vm.setAiCheck,
                ),
                AppButton(
                  'Analyze',
                  expand: true,
                  loading: vm.submitting,
                  onPressed: vm.canSubmit ? () => _submit(vm) : null,
                ),
              ],
            ),
          ),
          if (vm.problem == AnalyzeProblem.unreachable) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              tone: BannerTone.error,
              title: "Can't reach server",
              message: 'Check Tailscale and backend.',
              actions: [
                AppButton(
                  'Retry',
                  variant: AppButtonVariant.text,
                  onPressed: () => _submit(vm),
                ),
                AppButton(
                  'Change server',
                  variant: AppButtonVariant.text,
                  onPressed: () => context.push('/profile/server'),
                ),
              ],
            ),
          ],
          if (vm.problem == AnalyzeProblem.failed) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              tone: BannerTone.error,
              title: "Couldn't start",
              actions: [
                AppButton(
                  'Retry',
                  variant: AppButtonVariant.text,
                  onPressed: () => _submit(vm),
                ),
              ],
            ),
          ],
          SectionLabel(
            'Recent',
            trailing: TextButton(
              onPressed: () => context.go('/history'),
              child: const Text('See all'),
            ),
          ),
          ...switch (vm.recent) {
            Loading() => const [
              SizedBox(height: 200, child: SkeletonList(itemCount: 2)),
            ],
            Empty() => [Text('No checks yet', style: context.text.bodyMedium)],
            Failure(:final message) => [
              InfoBanner(
                tone: BannerTone.error,
                title: message,
                actions: [
                  AppButton(
                    'Retry',
                    variant: AppButtonVariant.text,
                    onPressed: vm.loadRecent,
                  ),
                ],
              ),
            ],
            Data(:final value) => [
              for (final entry in value)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: LibraryEntryCard(entry: entry, compact: true),
                ),
            ],
          },
        ],
      ),
    );
  }
}
