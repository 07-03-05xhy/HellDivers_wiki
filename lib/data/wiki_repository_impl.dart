import 'dart:async';

import 'local_store.dart';
import 'wiki_api_client.dart';
import 'wiki_models.dart';
import 'wiki_repository.dart';

/// [WikiRepository] 的默认实现：helldivers.wiki.gg MediaWiki API + 本地 SQLite。
class WikiRepositoryImpl implements WikiRepository {
  /// 无参构造即可用（main.dart 以 `WikiRepositoryImpl()` 创建）；
  /// 测试可注入伪装的 [apiClient] / [store]。
  WikiRepositoryImpl({WikiApiClient? apiClient, LocalStore? store})
      : _api = apiClient ?? WikiApiClient(),
        _store = store ?? LocalStore();

  /// 单次 pageimages 请求最多携带的标题数。
  static const int _pageImageBatchSize = 50;

  static final RegExp _htmlTag = RegExp('<[^>]*>');

  final WikiApiClient _api;
  final LocalStore _store;

  static String _stripHtml(String value) =>
      value.replaceAll(_htmlTag, '').trim();

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _queryMap(Map<String, dynamic> json) {
    final query = json['query'];
    if (query is Map<String, dynamic>) return query;
    throw const WikiApiException('响应缺少 query 字段');
  }

  // ---- 分类 ----

  @override
  Future<List<WikiCategory>> topCategories({int limit = 50}) async {
    final json = await _api.getJson(const {
      'action': 'query',
      'list': 'allcategories',
      'aclimit': '500',
    });
    final list = _queryMap(json)['allcategories'];
    if (list is! List) return const [];
    final categories = <WikiCategory>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final title = item['*'];
        if (title is String && title.isNotEmpty) {
          categories.add(WikiCategory(title: title, pages: _asInt(item['pages'])));
        }
      }
    }
    categories..removeWhere((c) => c.pages == 0)
      ..sort((a, b) => b.pages.compareTo(a.pages));
    return categories.take(limit).toList();
  }

  @override
  Future<({List<WikiPageSummary> items, String? cursor})> categoryMembers(
    String category, {
    String? cursor,
    int limit = 50,
  }) async {
    final json = await _api.getJson(<String, String>{
      'action': 'query',
      'list': 'categorymembers',
      'cmtitle': category,
      'cmtype': 'page',
      'cmlimit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cmcontinue': cursor,
    });
    final list = _queryMap(json)['categorymembers'];
    final items = <WikiPageSummary>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final title = item['title'];
          if (title is String) {
            items.add(WikiPageSummary(pageId: _asInt(item['pageid']), title: title));
          }
        }
      }
    }
    final cont = json['continue'];
    String? next;
    if (cont is Map<String, dynamic>) {
      final cm = cont['cmcontinue'];
      if (cm is String && cm.isNotEmpty) next = cm;
    }
    return (items: items, cursor: next);
  }

  // ---- 搜索 ----

  @override
  Future<List<WikiPageSummary>> search(String query, {int limit = 20}) async {
    final json = await _api.getJson(<String, String>{
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'srlimit': limit.toString(),
    });
    final list = _queryMap(json)['search'];
    if (list is! List) return const [];
    final results = <WikiPageSummary>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final title = item['title'];
        if (title is String) {
          final snippet = item['snippet'];
          results.add(WikiPageSummary(
            pageId: _asInt(item['pageid']),
            title: title,
            snippet: snippet is String ? snippet : '',
          ));
        }
      }
    }
    return results;
  }

  // ---- 条目 ----

  @override
  Future<WikiArticle> article(String title) async {
    final json = await _api.getJson(<String, String>{
      'action': 'parse',
      'page': title,
      'prop': 'text|sections|displaytitle',
      'formatversion': '2',
      'redirects': '1',
    });
    final parse = json['parse'];
    if (parse is! Map<String, dynamic>) {
      throw const WikiApiException('响应缺少 parse 字段');
    }
    final resolvedTitle =
        parse['title'] is String ? parse['title']! as String : title;
    final display = parse['displaytitle'];
    final displayTitle = display is String && display.isNotEmpty
        ? _stripHtml(display)
        : resolvedTitle;
    final text = parse['text'];
    final rawSections = parse['sections'];
    final sections = <WikiSection>[];
    if (rawSections is List) {
      for (final item in rawSections) {
        if (item is Map<String, dynamic>) {
          final line = item['line'];
          final anchor = item['anchor'];
          sections.add(WikiSection(
            index: _asInt(item['index']),
            anchor: anchor is String ? anchor : '',
            line: line is String ? _stripHtml(line) : '',
            level: _asInt(item['level']),
          ));
        }
      }
    }
    return WikiArticle(
      pageId: _asInt(parse['pageid']),
      title: resolvedTitle,
      displayTitle: displayTitle,
      html: text is String ? text : '',
      sections: sections,
      fetchedAt: DateTime.now(),
    );
  }

  // ---- 题图 ----

  @override
  Future<String?> pageImage(String title, {int width = 320}) async {
    final images = await pageImages([title], width: width);
    return images[title];
  }

  @override
  Future<Map<String, String>> pageImages(List<String> titles,
      {int width = 320}) async {
    final result = <String, String>{};
    if (titles.isEmpty) return result;
    for (var start = 0; start < titles.length; start += _pageImageBatchSize) {
      final end = (start + _pageImageBatchSize > titles.length)
          ? titles.length
          : start + _pageImageBatchSize;
      final chunk = titles.sublist(start, end);
      final json = await _api.getJson(<String, String>{
        'action': 'query',
        'prop': 'pageimages',
        'pithumbsize': width.toString(),
        'titles': chunk.join('|'),
        'formatversion': '2',
      });
      final pages = _queryMap(json)['pages'];
      if (pages is List) {
        for (final page in pages) {
          if (page is Map<String, dynamic>) {
            final title = page['title'];
            final thumb = page['thumbnail'];
            if (title is String && thumb is Map<String, dynamic>) {
              final source = thumb['source'];
              if (source is String && source.isNotEmpty) {
                result[title] = source;
              }
            }
          }
        }
      }
    }
    return result;
  }

  // ---- 收藏 ----

  @override
  Future<List<FavoriteEntry>> favorites() => _store.favorites();

  @override
  Future<void> addFavorite(int pageId, String title) =>
      _store.addFavorite(pageId, title);

  @override
  Future<void> removeFavorite(int pageId) => _store.removeFavorite(pageId);

  @override
  Future<bool> isFavorite(int pageId) => _store.isFavorite(pageId);

  // ---- 历史 ----

  @override
  Future<List<HistoryEntry>> history({int limit = 100}) =>
      _store.history(limit: limit);

  @override
  Future<void> recordVisit(int pageId, String title) =>
      _store.recordVisit(pageId, title);

  @override
  Future<void> clearHistory() => _store.clearHistory();

  @override
  void close() {
    _api.close();
    unawaited(_store.close());
  }
}
