import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_base_url_stub.dart' if (dart.library.io) 'api_base_url_io.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: '',
                  ))
              .ifEmpty(defaultApiBaseUrl())
              .replaceFirst(RegExp(r'/$'), '');

  final http.Client _httpClient;
  final String baseUrl;
  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> getJson(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('PATCH', path, body: body);
  }

  Future<void> deleteJson(String path) async {
    await _send('DELETE', path);
  }

  Future<Map<String, dynamic>> deleteJsonWithResponse(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    try {
      final response = switch (method) {
        'GET' => await _httpClient.get(uri, headers: headers),
        'DELETE' => await _httpClient.delete(uri, headers: headers),
        'PATCH' => await _httpClient.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => await _httpClient.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
      };
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final details = data['details'];
        final detailMessage =
            details is List && details.isNotEmpty && details.first is Map
            ? (details.first as Map)['message']?.toString()
            : null;
        throw ApiException(
          data['message']?.toString() ??
              detailMessage ??
              data['error']?.toString() ??
              'Request failed',
          statusCode: response.statusCode,
        );
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (error) {
      debugPrint('API request failed: $method $uri $error');
      throw const ApiException('Could not reach DukaanZone backend');
    }
  }
}

final apiClient = ApiClient();

extension _StringDefault on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
