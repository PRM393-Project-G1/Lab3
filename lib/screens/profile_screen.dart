import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/profile_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/remote_config_row.dart';
import '../widgets/section_label.dart';
import 'export_flow.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _testCrash(BuildContext context, ProfileViewModel vm) async {
    final confirmed = await showAppDialog(
      context,
      title: 'Test crash?',
      message: 'The app will close.',
      confirmLabel: 'Crash',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (confirmed) vm.testCrash();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = vm.user;
    final photo = user?.photoUrl;
    return Scaffold(
      appBar: const AppTopBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: photo == null ? null : NetworkImage(photo),
                  child: photo == null
                      ? const Icon(Icons.person_rounded)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    user?.displayName ?? '',
                    style: context.text.titleMedium,
                  ),
                ),
                AppButton(
                  'Sign out',
                  variant: AppButtonVariant.text,
                  onPressed: vm.signOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI check'),
              value: vm.aiCheck,
              onChanged: vm.setAiCheck,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Server', style: context.text.titleMedium),
                      Text(vm.serverUrl, style: context.mono),
                    ],
                  ),
                ),
                AppButton(
                  'Change',
                  variant: AppButtonVariant.text,
                  onPressed: () => context.push('/profile/server'),
                ),
              ],
            ),
          ),
          const SectionLabel('Firebase demo'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  'Notifications',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push('/notifications'),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  'Export report',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    final id = vm.latestDoneId;
                    if (id == null) {
                      _snack(context, 'No checks yet');
                    } else {
                      showExportSheet(context, id);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Remote Config', style: context.text.titleMedium),
                for (final (key, value) in vm.remoteConfigRows)
                  RemoteConfigRow(keyName: key, value: value),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  'Log error',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await vm.logError();
                    if (context.mounted) _snack(context, 'Error logged');
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  'Test crash',
                  variant: AppButtonVariant.destructive,
                  onPressed: () => _testCrash(context, vm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
