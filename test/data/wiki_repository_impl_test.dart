import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/local_store.dart';
import 'package:helldivers_wiki/data/wiki_api_client.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/data/wiki_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

typedef _Handler = Future<http.Response> Function(Map<String, String> query);

WikiRepository _repo(_Handler handler) {
  final mock = MockClient((request) => handler(request.url.queryParameters));
  return WikiRepositoryImpl(
    apiClient: WikiApiClient(client: mock),
    store: LocalStore(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    ),
  );
}

http.Response _json(Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  group('topCategories', () {
    test('按 pages 降序、过滤空分类、截取 limit', () async {
      Map<String, String>? seen;
      final repo = _repo((query) async {
        seen = query;
        return _json({
          'query': {
            'allcategories': [
              {'*': '小', 'pages': 2},
              {'*': '空', 'pages': 0},
              {'*': '大', 'pages': 100},
              {'*': '中', 'pages': 10},
              {'*': '隐藏', 'pages': 999, 'hidden': ''},
              {'*': 'Weapon templates', 'pages': 500},
              {'*': 'Articles to be expanded', 'pages': 400},
            ],
          },
        });
      });
      final cats = await repo.topCategories(limit: 2);
      expect(seen!['action'], 'query');
      expect(seen!['list'], 'allcategories');
      expect(seen!['aclimit'], '500');
      expect(seen!['acprop'], 'size|hidden');
      expect(cats.map((c) => c.title).toList(),
          ['Category:大', 'Category:中']);
      expect(cats.map((c) => c.pages).toList(), [100, 10]);
    });
  });

  group('categoryMembers', () {
    test('解析成员与 continue 游标', () async {
      final repo = _repo((query) async {
        expect(query['cmtitle'], 'Category:Weapons');
        expect(query['cmtype'], 'page');
        expect(query['cmnamespace'], '0');
        expect(query['cmlimit'], '10');
        return _json({
          'query': {
            'categorymembers': [
              {'pageid': 1, 'title': 'AR-23 解放者'},
              {'pageid': 2, 'title': 'P-19 救赎者'},
            ],
          },
          'continue': {'cmcontinue': 'page|abc|10'},
        });
      });
      final page = await repo.categoryMembers('Category:Weapons', limit: 10);
      expect(page.items, hasLength(2));
      expect(page.items.first.pageId, 1);
      expect(page.items.first.title, 'AR-23 解放者');
      expect(page.cursor, 'page|abc|10');
    });

    test('传入 cursor 时带 cmcontinue；无 continue 时游标为 null', () async {
      final seen = <Map<String, String>>[];
      final repo = _repo((query) async {
        seen.add(query);
        return _json({
          'query': {
            'categorymembers': [
              {'pageid': 3, 'title': 'SG-8 制裁者'},
            ],
          },
        });
      });
      final page = await repo.categoryMembers('Category:Weapons',
          cursor: 'page|abc|10');
      expect(seen.single['cmcontinue'], 'page|abc|10');
      expect(page.cursor, isNull);
      expect(page.items.single.pageId, 3);
    });
  });

  group('search', () {
    test('解析结果，snippet 保留原始 HTML', () async {
      Map<String, String>? seen;
      final repo = _repo((query) async {
        seen = query;
        return _json({
          'query': {
            'search': [
              {
                'pageid': 7,
                'title': '解放者',
                'snippet': '一把<span class="searchmatch">突击</span>步枪',
              },
            ],
          },
        });
      });
      final results = await repo.search('解放者', limit: 5);
      expect(seen!['list'], 'search');
      expect(seen!['srsearch'], '解放者');
      expect(seen!['srnamespace'], '0');
      expect(seen!['srlimit'], '5');
      expect(results.single.pageId, 7);
      expect(results.single.snippet, contains('searchmatch'));
    });
  });

  group('article', () {
    test('剥离 displaytitle/section 标签，index/level 转 int', () async {
      final repo = _repo((query) async {
        expect(query['action'], 'parse');
        expect(query['page'], '解放者');
        expect(query['prop'], 'text|sections|displaytitle');
        expect(query['formatversion'], '2');
        expect(query['redirects'], '1');
        return _json({
          'parse': {
            'pageid': 42,
            'title': '解放者',
            'displaytitle': '<span class="mw-page-title-main">解放者</span>',
            'text': '<p>正文</p>',
            'sections': [
              {
                'index': '1',
                'anchor': '概述',
                'line': '<b>概述</b>',
                'level': '2',
              },
              {'index': 2, 'anchor': '数据', 'line': '数据', 'level': 3},
            ],
          },
        });
      });
      final article = await repo.article('解放者');
      expect(article.pageId, 42);
      expect(article.title, '解放者');
      expect(article.displayTitle, '解放者');
      expect(article.html, '<p>正文</p>');
      expect(article.sections, hasLength(2));
      expect(article.sections[0].index, 1);
      expect(article.sections[0].line, '概述');
      expect(article.sections[0].level, 2);
      expect(article.sections[1].level, 3);
    });

    test('缺少 parse 字段抛 WikiApiException', () async {
      final repo = _repo((query) async => _json({'query': <String, dynamic>{}}));
      await expectLater(
        repo.article('不存在'),
        throwsA(isA<WikiApiException>()),
      );
    });
  });

  group('pageImage / pageImages', () {
    test('pageImage 返回 thumbnail.source，无题图返回 null', () async {
      final repo = _repo((query) async {
        expect(query['prop'], 'pageimages');
        expect(query['pithumbsize'], '640');
        return _json({
          'query': {
            'pages': [
              {
                'pageid': 1,
                'title': '有图',
                'thumbnail': {'source': 'https://x/img.png', 'width': 640},
              },
              {'pageid': 2, 'title': '无图'},
            ],
          },
        });
      });
      expect(await repo.pageImage('有图', width: 640), 'https://x/img.png');
      expect(await repo.pageImage('无图', width: 640), isNull);
    });

    test('pageImages 超过 50 个标题自动分批', () async {
      final titleParams = <String>[];
      final repo = _repo((query) async {
        titleParams.add(query['titles']!);
        final pages = <Map<String, dynamic>>[];
        for (final t in query['titles']!.split('|')) {
          pages.add({
            'title': t,
            'thumbnail': {'source': 'https://x/$t.png'},
          });
        }
        return _json({'query': {'pages': pages}});
      });
      final titles =
          List<String>.generate(120, (i) => 'T$i');
      final images = await repo.pageImages(titles);
      expect(titleParams, hasLength(3)); // 50 + 50 + 20
      expect(titleParams[0].split('|'), hasLength(50));
      expect(titleParams[2].split('|'), hasLength(20));
      expect(images, hasLength(120));
      expect(images['T119'], 'https://x/T119.png');
    });
  });

  group('错误传播', () {
    test('HTTP 错误向上抛 WikiApiException', () async {
      final repo = _repo(
          (query) async => http.Response('server error', 500));
      await expectLater(repo.topCategories(),
          throwsA(isA<WikiApiException>()));
      await expectLater(repo.search('x'),
          throwsA(isA<WikiApiException>()));
      await expectLater(repo.pageImage('x'),
          throwsA(isA<WikiApiException>()));
    });
  });

  group('收藏与历史委托', () {
    test('通过 repository 操作本地存储', () async {
      final repo = _repo((query) async => _json({'query': <String, dynamic>{}}));
      await repo.addFavorite(1, '解放者');
      expect(await repo.isFavorite(1), isTrue);
      expect((await repo.favorites()).single.title, '解放者');
      await repo.removeFavorite(1);
      expect(await repo.isFavorite(1), isFalse);

      await repo.recordVisit(9, '飞鹰');
      final history = await repo.history();
      expect(history.single.pageId, 9);
      await repo.clearHistory();
      expect(await repo.history(), isEmpty);
      repo.close();
    });
  });
}
