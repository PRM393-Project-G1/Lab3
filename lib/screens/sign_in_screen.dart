import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/auth_service.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/app_button.dart';
import '../widgets/info_banner.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: AppSizes.stateIconCircle / 2,
                  backgroundColor: context.colors.primaryContainer,
                  child: Icon(
                    Icons.account_tree_rounded,
                    size: AppSizes.iconLg,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Realtron', style: context.text.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Know what a paper stands on.',
                  style: context.text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ..._banner(vm.problem),
                AppButton(
                  'Continue with Google',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.g_mobiledata_rounded,
                  loading: vm.signingIn,
                  expand: true,
                  onPressed: vm.signIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _banner(SignInResult? problem) {
    final banner = switch (problem) {
      SignInResult.cancelled => const InfoBanner(
        tone: BannerTone.info,
        title: 'Sign-in cancelled',
      ),
      SignInResult.offline => const InfoBanner(
        tone: BannerTone.offline,
        title: "You're offline",
      ),
      SignInResult.failed => const InfoBanner(
        tone: BannerTone.error,
        title: 'Sign-in failed',
      ),
      _ => null,
    };
    return banner == null
        ? const []
        : [banner, const SizedBox(height: AppSpacing.md)];
  }
}
