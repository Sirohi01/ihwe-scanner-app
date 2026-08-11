import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.session);
  final SessionStore session;

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
    return _request(() => http.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return _request(
        () => http.post(uri, headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return _request(
        () => http.patch(uri, headers: _headers, body: jsonEncode(body)));
  }

  Future<Map<String, dynamic>> delete(String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return _request(() => http.delete(uri,
        headers: _headers, body: body == null ? null : jsonEncode(body)));
  }

  Future<http.Response> download(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
    final response = await _guard(() => http.get(uri, headers: _headers));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    return response;
  }

  Future<Map<String, dynamic>> uploadFile(
      String path, String fieldName, String filePath) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'ngrok-skip-browser-warning': 'true',
        if (session.token != null) 'Authorization': 'Bearer ${session.token}',
      })
      ..files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        if (session.token != null) 'Authorization': 'Bearer ${session.token}',
      };

  Map<String, dynamic> _decode(http.Response response) {
    dynamic parsed;
    try {
      parsed = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Server returned an invalid response. Please retry.');
    }
    final data = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) session.clear();
      if (response.statusCode >= 500) {
        throw ApiException(
            'Server is temporarily unavailable. Please try again.',
            response.statusCode);
      }
      throw ApiException(
          data['message']?.toString() ?? 'Request failed', response.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> _request(
          Future<http.Response> Function() request) async =>
      _decode(await _guard(request));

  Future<http.Response> _guard(
      Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ApiException('Unable to connect to the server.');
    } on http.ClientException {
      throw ApiException('Unable to connect to the server.');
    }
  }
}
