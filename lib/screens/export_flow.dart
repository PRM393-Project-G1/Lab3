import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_tokens.dart';
import '../viewmodels/export_view_model.dart';
import '../widgets/export_sheet.dart';

/// Opens the Export report sheet and starts creating the PDF right away.
Future<void> showExportSheet(BuildContext context, String analysisId) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => ChangeNotifierProvider(
      create: (c) => ExportViewModel(
        report: c.read(),
        files: c.read(),
        storage: c.read(),
        firestore: c.read(),
        analyses: c.read(),
        remoteConfig: c.read(),
        auth: c.read(),
        analytics: c.read(),
        crashlytics: c.read(),
        device: c.read(),
        analysisId: analysisId,
      )..start(),
      child: _ExportSheetBody(
        // A snackbar would sit under the sheet, so the sheet closes first.
        onMessage: (message) {
          Navigator.of(sheetContext).pop();
          messenger.showSnackBar(SnackBar(content: Text(message)));
        },
      ),
    ),
  );
}

class _ExportSheetBody extends StatelessWidget {
  const _ExportSheetBody({required this.onMessage});

  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExportViewModel>();
    return ExportSheet(
      stage: switch (vm.phase) {
        ExportPhase.creating => ExportStage.creating,
        ExportPhase.uploading => ExportStage.uploading,
        ExportPhase.uploaded => ExportStage.uploaded,
        ExportPhase.saved => ExportStage.saved,
        ExportPhase.failed => ExportStage.failed,
      },
      progress: vm.progress,
      fileLabel: vm.fileLabel,
      onCopyLink: () async {
        await vm.copyLink();
        onMessage('Link copied');
      },
      onOpen: () async {
        if (!await vm.open()) onMessage('No app can open PDF');
      },
      onShare: vm.share,
      onRetry: vm.start,
    );
  }
}
