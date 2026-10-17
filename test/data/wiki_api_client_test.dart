import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_api_client.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Client _ok(Map<String, dynamic> body, {void Function(http.Request)? onRequest}) {
  return MockClient((request) async {
    onRequest?.call(request);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
}

void main() {
  group('WikiApiClient', () {
    test('成功响应返回解码 JSON，并携带 UA 与 format=json', () async {
      http.Request? seen;
      final client = WikiApiClient(
        client: _ok({'query': {'a': 1}}, onRequest: (r) => seen = r),
      );
      final json = await client.getJson(const {'action': 'query'});
      expect((json['query']! as Map<String, dynamic>)['a'], 1);
      expect(seen, isNotNull);
      expect(seen!.headers['User-Agent'], kWikiUserAgent);
      expect(seen!.url.queryParameters['format'], 'json');
      expect(seen!.url.queryParameters['action'], 'query');
    });

    test('HTTP 非 200 抛 WikiApiException 且含状态码', () async {
      final client = WikiApiClient(
        client: MockClient((request) async => http.Response('boom', 503)),
      );
      await expectLater(
        client.getJson(const {'action': 'query'}),
        throwsA(isA<WikiApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)),
      );
    });

    test('MediaWiki error 字段抛 WikiApiException', () async {
      final client = WikiApiClient(
        client: _ok({'error': {'code': 'badtitle', 'info': 'Invalid title'}}),
      );
      await expectLater(
        client.getJson(const {'action': 'query'}),
        throwsA(isA<WikiApiException>()
            .having((e) => e.message, 'message', contains('badtitle'))),
      );
    });

    test('非法 JSON 抛 WikiApiException', () async {
      final client = WikiApiClient(
        client: MockClient((request) async => http.Response('not json', 200)),
      );
      await expectLater(
        client.getJson(const {'action': 'query'}),
        throwsA(isA<WikiApiException>()),
      );
    });
  });
}
