import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class TmdbApiException implements Exception {
  final int statusCode;
  final String message;
  const TmdbApiException(this.statusCode, this.message);

  @override
  String toString() => 'TmdbApiException($statusCode): $message';
}

class TmdbClient {
  final http.Client _client;

  TmdbClient({http.Client? client}) : _client = client ?? http.Client();

  static const Set<int> _retryableStatusCodes = {429, 500, 502, 503, 504};
  static const int _maxAttempts = 3;

  String get _baseUrl => AppConfig.usesTmdbProxy
      ? AppConfig.tmdbProxyUrl.replaceAll(RegExp(r'/+$'), '')
      : 'https://api.themoviedb.org';

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> query = const {},
  }) async {
    if (!AppConfig.hasMovieApi) {
      throw const TmdbApiException(
        0,
        'Movie API is not configured. Set TMDB_PROXY_URL (recommended) or TMDB_ACCESS_TOKEN.',
      );
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final headers = <String, String>{'Accept': 'application/json'};
    if (!AppConfig.usesTmdbProxy) {
      headers['Authorization'] = 'Bearer ${AppConfig.tmdbAccessToken}';
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      http.Response response;
      try {
        response = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 18));
      } on TimeoutException {
        if (attempt < _maxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw const TmdbApiException(
          0,
          'TMDB request timed out. Check your connection and try again.',
        );
      }

      final data = _decodeObject(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }

      final message = (data['status_message'] ??
              data['message'] ??
              response.reasonPhrase ??
              'Request failed')
          .toString();

      if (_retryableStatusCodes.contains(response.statusCode) &&
          attempt < _maxAttempts) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        if (retryAfter != null && retryAfter > 0) {
          await Future<void>.delayed(
            Duration(seconds: retryAfter.clamp(1, 5).toInt()),
          );
        } else {
          await _backoff(attempt);
        }
        continue;
      }

      throw TmdbApiException(response.statusCode, message);
    }

    throw const TmdbApiException(0, 'TMDB request failed after retries.');
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } on FormatException {
      // Some upstream 5xx responses can be HTML/plain text. The status code
      // still drives retry/error handling, so a JSON body is not required.
    }
    return <String, dynamic>{};
  }

  Future<void> _backoff(int attempt) => Future<void>.delayed(
        Duration(milliseconds: 450 * attempt),
      );

  void dispose() => _client.close();
}
