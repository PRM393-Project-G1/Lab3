import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../theme/app_tokens.dart';
import '../utils/time_format.dart';
import '../viewmodels/notifications_view_model.dart';
import '../viewmodels/view_state.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/notification_tile.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/state_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();
    return Scaffold(
      appBar: const AppTopBar(title: 'Notifications'),
      body: switch (vm.state) {
        Loading() => const SkeletonList(),
        Failure() => StateView.error(onAction: vm.load),
        Empty() => const StateView.empty(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications',
        ),
        Data(:final value) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = value[index];
            return NotificationTile(
              title: item.title,
              body: item.body,
              timeLabel: timeAgo(item.createdAt),
              unread: !item.read,
              onTap: () async {
                final analysisId = await vm.open(item);
                if (!context.mounted) return;
                // An admin message always shows in full; a linked paper is one tap away.
                if (item.type == 'admin_message') {
                  final openPaper = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(item.title),
                      content: SingleChildScrollView(child: Text(item.body)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Close'),
                        ),
                        if (analysisId != null)
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Open paper'),
                          ),
                      ],
                    ),
                  );
                  if (openPaper == true &&
                      analysisId != null &&
                      context.mounted) {
                    context.push(AppRoutes.overview(analysisId));
                  }
                } else if (analysisId != null) {
                  context.push(AppRoutes.overview(analysisId));
                }
              },
            );
          },
        ),
      },
    );
  }
}
