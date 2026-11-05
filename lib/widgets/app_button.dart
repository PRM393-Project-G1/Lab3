import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';
import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, text, destructive }

/// Button with the design-system variants. A null [onPressed] means disabled;
/// [loading] disables it too and shows a spinner in place of the icon.
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final action = loading ? null : onPressed;
    final leading = loading
        ? const SizedBox.square(
            dimension: AppSizes.spinnerSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
        ? null
        : Icon(icon);
    final child = Text(label);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton.icon(
        onPressed: action,
        icon: leading,
        label: child,
      ),
      AppButtonVariant.secondary => OutlinedButton.icon(
        onPressed: action,
        icon: leading,
        label: child,
      ),
      AppButtonVariant.text => TextButton.icon(
        onPressed: action,
        icon: leading,
        label: child,
      ),
      AppButtonVariant.destructive => FilledButton.icon(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.error,
          foregroundColor: context.colors.onError,
        ),
        icon: leading,
        label: child,
      ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
