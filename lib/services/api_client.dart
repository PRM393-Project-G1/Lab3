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

abstract class ApiClient {
  /// Checks a server address and returns the round trip in milliseconds.
  Future<int> health(String baseUrl);
  Future<void> startAnalysis(String arxivId, {required bool aiAssisted});
  Future<void> cancelAnalysis(String arxivId);
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

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final base = _settings.serverUrl;
    if (base == null) throw const ApiException(ApiFailure.noServer);
    final token = await _auth.idToken();
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
    } on http.ClientException {
      throw const ApiException(ApiFailure.unreachable);
    }
  }
}
