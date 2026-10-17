import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wiki_models.dart';

/// MediaWiki API 调用失败时抛出的异常。
class WikiApiException implements Exception {
  const WikiApiException(this.message, {this.statusCode});

  /// 人类可读的错误描述。
  final String message;

  /// HTTP 状态码；非 HTTP 层错误（解析失败、API 层报错）时为 null。
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'WikiApiException: $message'
      : 'WikiApiException($statusCode): $message';
}

/// MediaWiki API 的薄封装：统一 UA、超时、format=json 与错误处理。
class WikiApiClient {
  WikiApiClient({http.Client? client, String apiBase = kWikiApiBase})
      : _client = client ?? http.Client(),
        _apiBase = apiBase;

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _apiBase;

  /// 发起 GET 请求并返回解码后的 JSON 对象。
  ///
  /// [params] 中无需带 format，统一在此追加 format=json。
  /// HTTP 非 200、JSON 解析失败或响应含 MediaWiki error 字段时
  /// 抛 [WikiApiException]。
  Future<Map<String, dynamic>> getJson(Map<String, String> params) async {
    final query = <String, String>{...params, 'format': 'json'};
    final uri = Uri.parse(_apiBase).replace(queryParameters: query);

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'User-Agent': kWikiUserAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw const WikiApiException('请求超时（15s）');
    }

    if (response.statusCode != 200) {
      throw WikiApiException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase ?? ''}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw WikiApiException('响应不是合法 JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WikiApiException('响应 JSON 不是对象');
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final info = error['info'];
      final code = error['code'];
      throw WikiApiException('MediaWiki 错误 [$code]: $info');
    }

    return decoded;
  }

  /// 关闭底层 HTTP 客户端。
  void close() => _client.close();
}
