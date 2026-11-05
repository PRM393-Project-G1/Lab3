import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Text another app shared into Realtron, such as an arXiv link.
abstract class ShareIntentService {
  Future<String?> initialText();
  Stream<String> get incomingText;
  void clear();
}

class SystemShareIntentService implements ShareIntentService {
  // The plugin keeps shared text in `path` for SharedMediaType.text.
  String? _firstText(List<SharedMediaFile> files) {
    for (final file in files) {
      if (file.type == SharedMediaType.text ||
          file.type == SharedMediaType.url) {
        return file.path;
      }
    }
    return null;
  }

  @override
  Future<String?> initialText() async =>
      _firstText(await ReceiveSharingIntent.instance.getInitialMedia());

  @override
  Stream<String> get incomingText => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(_firstText)
      .where((text) => text != null)
      .cast<String>();

  @override
  void clear() => ReceiveSharingIntent.instance.reset();
}
