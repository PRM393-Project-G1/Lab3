import 'package:flutter/material.dart';

import 'app_button.dart';

/// Shows a confirmation dialog. Completes with true when confirmed.
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      message: message,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirm: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
    ),
  );
  return confirmed ?? false;
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
    this.destructive = false,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool destructive;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: content ?? (message == null ? null : Text(message!)),
    actions: [
      AppButton(
        cancelLabel,
        onPressed: onCancel,
        variant: AppButtonVariant.text,
      ),
      AppButton(
        confirmLabel,
        onPressed: onConfirm,
        variant: destructive
            ? AppButtonVariant.destructive
            : AppButtonVariant.primary,
      ),
    ],
  );
}
