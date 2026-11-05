import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class UploadedFile {
  const UploadedFile({required this.path, required this.url});

  final String path;
  final String url;
}

abstract class StorageService {
  Future<UploadedFile> uploadReport({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  });
}

class FirebaseStorageService implements StorageService {
  FirebaseStorageService({FirebaseStorage? storage}) : _override = storage;

  final FirebaseStorage? _override;

  /// Resolved on upload: `FirebaseStorage.instance` throws when the project
  /// has no bucket, as on the Spark plan.
  FirebaseStorage get _storage => _override ?? FirebaseStorage.instance;

  @override
  Future<UploadedFile> uploadReport({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  }) async {
    // The SDK default of 10 minutes would look like a stuck upload.
    _storage.setMaxUploadRetryTime(const Duration(seconds: 30));
    final ref = _storage.ref('reports/$uid/$fileName');
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final sub = task.snapshotEvents.listen((snap) {
      if (snap.totalBytes > 0) {
        onProgress(snap.bytesTransferred / snap.totalBytes);
      }
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    return UploadedFile(path: ref.fullPath, url: await ref.getDownloadURL());
  }
}
