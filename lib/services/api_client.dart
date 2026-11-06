import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../firebase/auth_service.dart';
import 'server_settings.dart';

/// Why a backend call failed. Each kind has its own message on screen.
enum ApiFailure { noServer, unreachable, timeout, notRealtron, rejected }

class ApiException implements Exception {
  const ApiException(this.failure);

  final ApiFailure failure;

  @override
  String toString() => 'ApiException($failure)';
}

/// Where to send one report upload, and the form fields the backend signed.
class UploadTicket {
  const UploadTicket({required this.uploadUrl, required this.fields});

  final String uploadUrl;
  final Map<String, String> fields;
}

abstract class ApiClient {
  /// Checks a server address and returns the round trip in milliseconds.
  Future<int> health(String baseUrl);
  Future<void> startAnalysis(String arxivId, {required bool aiAssisted});
  Future<void> cancelAnalysis(String arxivId);

  /// Asks the backend to sign an upload of [fileName] into the user's folder.
  Future<UploadTicket> signUpload(String fileName);
}

class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this._settings,
    required this._auth,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _healthTimeout = Duration(seconds: 5);
  static const _commandTimeout = Duration(seconds: 15);

  final ServerSettings _settings;
  final AuthService _auth;
  final http.Client _client;

  @override
  Future<int> health(String baseUrl) async {
    final watch = Stopwatch()..start();
    final response = await _guard(
      () => _client.get(Uri.parse('$baseUrl/api/health')),
      _healthTimeout,
    );
    watch.stop();
    if (response.statusCode != 200) {
      throw const ApiException(ApiFailure.notRealtron);
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'ok') {
        throw const ApiException(ApiFailure.notRealtron);
      }
    } on FormatException {
      throw const ApiException(ApiFailure.notRealtron);
    } on TypeError {
      throw const ApiException(ApiFailure.notRealtron);
    }
    return watch.elapsedMilliseconds;
  }

  @override
  Future<void> startAnalysis(String arxivId, {required bool aiAssisted}) =>
      _post('/api/analyses', {'arxivId': arxivId, 'aiAssisted': aiAssisted});

  @override
  Future<void> cancelAnalysis(String arxivId) =>
      _post('/api/analyses/$arxivId/cancel', const {});

  @override
  Future<UploadTicket> signUpload(String fileName) async {
    final response = await _post('/api/uploads/signature', {
      'fileName': fileName,
    });
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = body['fields'] as Map<String, dynamic>;
      return UploadTicket(
        uploadUrl: body['uploadUrl'] as String,
        fields: fields.map((key, value) => MapEntry(key, '$value')),
      );
    } on FormatException {
      throw const ApiException(ApiFailure.notRealtron);
    } on TypeError {
      throw const ApiException(ApiFailure.notRealtron);
    }
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final base = _settings.serverUrl;
    if (base == null) throw const ApiException(ApiFailure.noServer);
    final String? token;
    try {
      token = await _auth.idToken();
    } catch (_) {
      // Refreshing an expired token needs the network too.
      throw const ApiException(ApiFailure.unreachable);
    }
    final response = await _guard(
      () => _client.post(
        Uri.parse('$base$path'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ),
      _commandTimeout,
    );
    if (response.statusCode >= 300) {
      throw const ApiException(ApiFailure.rejected);
    }
    return response;
  }

  Future<http.Response> _guard(
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    try {
      return await call().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiFailure.timeout);
    } on SocketException {
      throw const ApiException(ApiFailure.unreachable);
    } on TlsException {
      throw const ApiException(ApiFailure.unreachable);
    } on http.ClientException {
      throw const ApiException(ApiFailure.unreachable);
    }
  }
}
