import 'dart:convert';
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
    return _decode(await http.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return _decode(
        await http.post(uri, headers: _headers, body: jsonEncode(body)));
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (session.token != null) 'Authorization': 'Bearer ${session.token}',
      };

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic parsed =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final data = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) session.clear();
      throw ApiException(
          data['message']?.toString() ?? 'Request failed', response.statusCode);
    }
    return data;
  }
}
