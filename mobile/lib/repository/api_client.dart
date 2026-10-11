import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../model/api_exception.dart';

/// HTTP 客户端。只管三件事：拼 URL、注入 Bearer、拆统一信封。
///
/// 页面永远拿不到 code —— 非 0 一律抛 [ApiException]，调用方只管 try/catch。
/// 契约第一节定的是"HTTP 状态码只表达传输层语义"，所以这里不按 statusCode 分流业务。
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  static const Duration _timeout = Duration(seconds: 15);

  void setToken(String? token) => _accessToken = token;

  String? get accessToken => _accessToken;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse(Env.apiBase);
    if (query == null || query.isEmpty) {
      return base.replace(path: path);
    }
    final params = <String, String>{};
    query.forEach((k, v) {
      if (v != null) params[k] = '$v';
    });
    return base.replace(path: path, queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.headers['Accept'] = 'application/json';
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(-1, '请求超时，确认后端已启动（${Env.apiBase}）');
    } catch (e) {
      throw ApiException(-1, '连不上后端 ${Env.apiBase}：$e');
    }

    final text = utf8.decode(response.bodyBytes);
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(-1, '响应不是合法 JSON（HTTP ${response.statusCode}）');
    }

    final code = (envelope['code'] as num?)?.toInt() ?? -1;
    if (code != 0) {
      throw ApiException(code, (envelope['message'] as String?) ?? '请求失败');
    }
    return envelope['data'];
  }

  void close() => _client.close();
}
