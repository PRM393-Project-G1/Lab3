import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Clipboard, external browser and system share, behind one testable interface.
abstract class DeviceActions {
  Future<void> copy(String text);
  Future<String?> paste();
  Future<void> openUrl(String url);
  Future<void> searchWeb(String query);
  Future<void> share(String text);

  /// Returns false when no installed app can open the PDF.
  Future<bool> openPdf(String path);
  Future<void> sharePdf(String path);
}

class SystemDeviceActions implements DeviceActions {
  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> paste() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  Future<void> openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Future<void> searchWeb(String query) =>
      openUrl(Uri.https('www.google.com', '/search', {'q': query}).toString());

  @override
  Future<void> share(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Future<bool> openPdf(String path) async {
    final result = await OpenFilex.open(path, type: 'application/pdf');
    return result.type == ResultType.done;
  }

  @override
  Future<void> sharePdf(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'application/pdf')]),
    );
  }
}
