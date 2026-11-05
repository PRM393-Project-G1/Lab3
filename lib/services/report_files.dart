import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// PDF reports kept on this device, one folder per user.
abstract class ReportFiles {
  /// Writes the file and returns its path.
  Future<String> save({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  });

  /// Removes every saved report, so the next user on this device finds none.
  Future<void> clear();
}

class DeviceReportFiles implements ReportFiles {
  Future<Directory> _root() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/reports');

  @override
  Future<String> save({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final folder = Directory('${(await _root()).path}/$uid');
    await folder.create(recursive: true);
    final file = File('${folder.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
