import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Centred empty or error state: icon, short title, optional action.
class StateView extends StatelessWidget {
  const StateView.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : isError = false;

  const StateView.error({
    super.key,
    this.icon = Icons.cloud_off_rounded,
    this.title = "Couldn't load",
    this.message,
    this.actionLabel = 'Retry',
    this.onAction,
  }) : isError = true;

  final IconData icon;
  final String title;

  /// An optional sentence under the title that explains the state.
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.stateIconCircle,
              height: AppSizes.stateIconCircle,
              decoration: BoxDecoration(
                color: isError
                    ? colors.errorContainer
                    : colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconLg,
                color: isError ? colors.error : colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: context.text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                actionLabel!,
                onPressed: onAction,
                icon: isError ? Icons.refresh_rounded : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
