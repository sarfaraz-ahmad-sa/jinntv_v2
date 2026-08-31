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

    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (!AppConfig.usesTmdbProxy) {
      headers['Authorization'] = 'Bearer ${AppConfig.tmdbAccessToken}';
    }

    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 18));

    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        json = decoded.cast<String, dynamic>();
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (json['status_message'] ?? json['message'] ?? response.reasonPhrase ?? 'Request failed').toString();
      throw TmdbApiException(response.statusCode, message);
    }

    return json;
  }

  void dispose() => _client.close();
}
