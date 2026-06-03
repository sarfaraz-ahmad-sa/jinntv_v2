import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiHttpException implements Exception {
  final int statusCode;
  final String body;
  final Uri uri;
  ApiHttpException(this.statusCode, this.body, this.uri);
  @override
  String toString() => 'HTTP $statusCode for $uri: $body';
}

class ApiParseException implements Exception {
  final String body;
  final Uri uri;
  ApiParseException(this.body, this.uri);
  @override
  String toString() => 'Invalid JSON for $uri: $body';
}

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  final Duration timeout;
  final int maxRetries;

  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
  }) : _client = client ?? http.Client();

  Future<String> _getOrCreateJinnCookie() async {
    final sp = await SharedPreferences.getInstance();
    var v = sp.getString('jinntv_cookie');
    if (v != null && v.isNotEmpty) return v;

    v = DateTime.now().microsecondsSinceEpoch.toString();
    await sp.setString('jinntv_cookie', v);
    return v;
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final safePath = path.startsWith('/') ? path : '/$path';
    Uri uri = Uri.parse(baseUrl).resolve(safePath);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    return uri;
  }

  bool _shouldRetry(int? statusCode, Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is HttpException) return true;
    if (statusCode != null && statusCode >= 500 && statusCode <= 599) return true;
    return false;
  }

  Duration _backoff(int attemptIndex) {
    // 0->300ms, 1->1200ms, 2->2700ms...
    final ms = 300 * (attemptIndex + 1) * (attemptIndex + 1);
    return Duration(milliseconds: ms);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final cookie = await _getOrCreateJinnCookie();
    final uri = _buildUri(path, query);

    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'Cookie': 'jinntv=$cookie',
      ...?headers,
    };

    http.Response? lastRes;
    Object? lastErr;

    final totalAttempts = 1 + maxRetries;
    for (int attempt = 0; attempt < totalAttempts; attempt++) {
      try {
        final res = await _client.get(uri, headers: mergedHeaders).timeout(timeout);
        lastRes = res;

        if (res.statusCode != 200) {
          final ex = ApiHttpException(res.statusCode, res.body, uri);
          if (_shouldRetry(res.statusCode, ex) && attempt < totalAttempts - 1) {
            await Future.delayed(_backoff(attempt));
            continue;
          }
          throw ex;
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          throw ApiParseException(res.body, uri);
        }
        return decoded;
      } catch (e) {
        lastErr = e;
        final retryable = _shouldRetry(lastRes?.statusCode, e is Object ? e : Exception('$e'));
        final canRetry = attempt < totalAttempts - 1;

        if (retryable && canRetry) {
          await Future.delayed(_backoff(attempt));
          continue;
        }
        rethrow;
      }
    }

    if (lastErr != null) throw lastErr!;
    throw Exception('Unknown API error for $uri');
  }

  void dispose() => _client.close();
}
