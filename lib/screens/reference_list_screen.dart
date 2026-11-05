import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/reference_list_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/reference_card.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';

class ReferenceListScreen extends StatelessWidget {
  const ReferenceListScreen({super.key});

  String _label(ReferenceFilter filter) {
    if (filter == ReferenceFilter.all) return 'All';
    if (filter == ReferenceFilter.unclassified) return 'Unclassified';
    return filter.status!.label;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReferenceListViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'References'),
      body: switch (vm.state) {
        Loading() || Empty() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Data() => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            if (vm.paperTitle != null)
              Text(vm.paperTitle!, style: context.text.titleLarge),
            Text('${vm.totalCount} refs', style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Search',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: vm.setQuery,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final filter in vm.filters)
                  AppFilterChip(
                    label: _label(filter),
                    count: vm.countOf(filter),
                    selected: vm.filter == filter,
                    onSelected: (_) => vm.setFilter(filter),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (vm.visible.isEmpty)
              const StateView.empty(
                icon: Icons.filter_alt_off_outlined,
                title: 'Nothing here',
              ),
            for (final ref in vm.visible)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ReferenceCard(
                  status: ref.status,
                  title: ref.title,
                  byline: ref.byline,
                  issue: ref.firstIssue,
                  onTap: () => context.push(
                    '/analyses/${vm.analysisId}/references/${ref.id}',
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
