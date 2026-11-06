import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../firebase/storage_service.dart';
import 'api_client.dart';

/// Uploads reports to Cloudinary while the Firebase project has no Storage
/// bucket (the Spark plan).
///
/// The backend signs each upload for `reports/{uid}/`, taking the uid from the
/// Firebase token. So the secret stays on the server, and a user cannot write
/// into another user's folder. Switch back to [FirebaseStorageService] in
/// `main.dart` once the project has a bucket.
class CloudinaryStorageService implements StorageService {
  CloudinaryStorageService({required this._api, http.Client? client})
    : _client = client ?? http.Client();

  // Same feel as the Firebase upload: longer than this looks stuck.
  static const _timeout = Duration(seconds: 30);

  final ApiClient _api;
  final http.Client _client;

  @override
  Future<UploadedFile> uploadReport({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  }) async {
    final ticket = await _api.signUpload(fileName);
    final form = http.MultipartRequest('POST', Uri.parse(ticket.uploadUrl))
      ..fields.addAll(ticket.fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final response = await http.Response.fromStream(
      await _client.send(_ProgressRequest(form, onProgress)),
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Cloudinary answered ${response.statusCode}',
        form.url,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return UploadedFile(
      path: body['public_id'] as String,
      url: body['secure_url'] as String,
    );
  }
}

/// [http.MultipartRequest] reports no progress, so this counts its body as the
/// client reads it.
class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(this._form, this._onProgress)
    : super(_form.method, _form.url) {
    contentLength = _form.contentLength;
  }

  final http.MultipartRequest _form;
  final void Function(double progress) _onProgress;

  @override
  http.ByteStream finalize() {
    final total = _form.contentLength;
    final body = _form.finalize();
    // The form sets its multipart boundary while finalizing.
    headers.addAll(_form.headers);
    super.finalize();
    var sent = 0;
    return http.ByteStream(
      body.map((chunk) {
        sent += chunk.length;
        if (total > 0) _onProgress(sent / total);
        return chunk;
      }),
    );
  }
}
