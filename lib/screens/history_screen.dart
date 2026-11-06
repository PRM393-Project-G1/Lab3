import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/library_entry.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/history_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/section_label.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';
import 'library_entry_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'History'),
      body: switch (vm.state) {
        Loading() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Empty() => StateView.empty(
          icon: Icons.history_rounded,
          title: 'No checks yet',
          actionLabel: 'Analyze a paper',
          onAction: () => context.go(AppRoutes.analyze),
        ),
        Data() => _Content(vm: vm),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.vm});

  final HistoryViewModel vm;

  static String _label(HistoryPeriod period) => switch (period) {
    HistoryPeriod.today => 'Today',
    HistoryPeriod.thisWeek => 'This week',
    HistoryPeriod.earlier => 'Earlier',
  };

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _rename(BuildContext context, LibraryEntry entry) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: entry.title),
    );
    if (title == null || title.trim().isEmpty) return;
    final saved = await vm.rename(entry, title);
    if (!saved && context.mounted) _snack(context, "Couldn't save");
  }

  Future<void> _delete(BuildContext context, LibraryEntry entry) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Delete check?',
      message: 'Removed from your history.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (!confirmed) return;
    final deleted = await vm.delete(entry);
    if (context.mounted) {
      _snack(context, deleted ? 'Deleted' : "Couldn't delete");
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = vm.groups();
    return RefreshIndicator(
      onRefresh: () async => vm.load(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppTextField(
            label: 'Search',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onChanged: vm.setQuery,
          ),
          if (groups.isEmpty)
            const StateView.empty(
              icon: Icons.search_off_rounded,
              title: 'No results',
            ),
          for (final group in groups) ...[
            SectionLabel(_label(group.period)),
            for (final entry in group.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LibraryEntryCard(
                  entry: entry,
                  onOpen: () => vm.touch(entry),
                  onRename: () => _rename(context, entry),
                  onDelete: () => _delete(context, entry),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _title;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Rename',
    content: AppTextField(label: 'Title', controller: _title),
    confirmLabel: 'Save',
    cancelLabel: 'Cancel',
    onConfirm: () => Navigator.of(context).pop(_title.text),
    onCancel: () => Navigator.of(context).pop(),
  );
}
