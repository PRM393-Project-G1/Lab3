import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../services/api_client.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/connect_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/info_banner.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, this.fromProfile = false});

  /// Opened from Profile: Save and go back instead of Continue.
  final bool fromProfile;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<ConnectViewModel>().url);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save(ConnectViewModel vm) async {
    await vm.save();
    if (!mounted) return;
    widget.fromProfile ? context.pop() : context.go(AppRoutes.analyze);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConnectViewModel>();
    final testing = vm.status == ConnectStatus.testing;
    return Scaffold(
      appBar: const AppTopBar(title: 'Connect server'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            child: AppTextField(
              label: 'Server URL',
              helper: 'e.g. http://100.x.x.x:8000',
              controller: _url,
              keyboardType: TextInputType.url,
              errorText: vm.status == ConnectStatus.empty
                  ? 'Enter a server URL'
                  : null,
              onChanged: vm.setUrl,
              onSubmitted: (_) => vm.test(),
              onPaste: () async {
                final text = await vm.paste();
                if (text != null) _url.text = text;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (vm.status == ConnectStatus.connected) ...[
            InfoBanner(
              tone: BannerTone.success,
              title: 'Connected · ${vm.latencyMs} ms',
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (vm.status == ConnectStatus.failed) ...[
            _FailureBanner(failure: vm.failure, onRetry: vm.test),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            testing ? 'Testing…' : 'Test',
            variant: AppButtonVariant.secondary,
            loading: testing,
            expand: true,
            onPressed: vm.test,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            widget.fromProfile ? 'Save' : 'Continue',
            expand: true,
            onPressed: vm.canSave ? () => _save(vm) : null,
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure, required this.onRetry});

  final ApiFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = AppButton(
      'Retry',
      variant: AppButtonVariant.text,
      onPressed: onRetry,
    );
    return switch (failure) {
      ApiFailure.timeout => InfoBanner(
        tone: BannerTone.error,
        title: 'Timed out',
        actions: [retry],
      ),
      ApiFailure.notRealtron => InfoBanner(
        tone: BannerTone.error,
        title: 'Not a Realtron server',
        actions: [retry],
      ),
      _ => InfoBanner(
        tone: BannerTone.error,
        title: "Can't reach server",
        actions: [
          for (final hint in const [
            'Tailscale on?',
            'Backend running?',
            'Using http://?',
          ])
            Chip(label: Text(hint)),
          retry,
        ],
      ),
    };
  }
}
