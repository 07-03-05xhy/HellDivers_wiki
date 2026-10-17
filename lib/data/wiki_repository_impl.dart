import 'dart:async';

import 'local_store.dart';
import 'wiki_api_client.dart';
import 'wiki_html_sanitizer.dart';
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

  /// 首页分类索引要剔除的维护/模板类分类关键词（wiki.gg 上这类
  /// 分类成员数很多但对读者是噪声）。
  static final RegExp _maintenanceCategory = RegExp(
    r'templates?|icons|images|maintenance|wip\b|articles|needing|needs\b'
    r'|sprite|audio|disambiguation|documentation|categories for|'
    r'main page|escaped character',
    caseSensitive: false,
  );

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

  /// allcategories 单次最多 500 条，全量翻页的安全批次上限。
  static const int _categoryScanBatches = 10;

  @override
  Future<List<WikiCategory>> topCategories({int limit = 50}) async {
    // allcategories 按字母序返回，该 wiki 分类多，中文分类排在 ASCII 之后，
    // 只拉第一页会漏掉所有中文分类 —— 必须翻页扫全量再按成员数排序。
    final categories = <WikiCategory>[];
    String? cursor;
    for (var batch = 0; batch < _categoryScanBatches; batch++) {
      final json = await _api.getJson(<String, String>{
        'action': 'query',
        'list': 'allcategories',
        // 不传 acprop 时该 wiki 只返回名字，没有 pages 字段（会把首页过滤空）。
        'acprop': 'size|hidden',
        'aclimit': '500',
        if (cursor != null) 'accontinue': cursor,
      });
      final list = _queryMap(json)['allcategories'];
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final title = item['*'];
            // 隐藏分类（hidden 键存在即隐藏）与维护类分类不展示。
            if (title is String &&
                title.isNotEmpty &&
                !item.containsKey('hidden') &&
                !_maintenanceCategory.hasMatch(title)) {
              // allcategories 的 * 不带 Category: 前缀，补上才能直接用于
              // categoryMembers(cmtitle:) 与 CategoryPage 导航。
              categories.add(WikiCategory(
                  title: 'Category:' + title, pages: _asInt(item['pages'])));
            }
          }
        }
      }
      final cont = json['continue'];
      cursor = cont is Map<String, dynamic> ? cont['accontinue'] as String? : null;
      if (cursor == null || cursor.isEmpty) break;
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
      // 只取主命名空间，排除 Community:/File: 等命名空间的杂项。
      'cmnamespace': '0',
      'cmlimit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cmcontinue': cursor,
    });
    final list = _queryMap(json)['categorymembers'];
    final items = <WikiPageSummary>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final title = item['title'];
          // "Community:" 其实是主命名空间里以它开头的伪命名空间标题
          // （愚人节整活页），服务端命名空间过滤挡不住，客户端剔除。
          if (title is String && !title.startsWith('Community:')) {
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
      // 只搜主命名空间，避免 Community: 愚人节页面等混入。
      'srnamespace': '0',
      'srlimit': limit.toString(),
    });
    final list = _queryMap(json)['search'];
    if (list is! List) return const [];
    final results = <WikiPageSummary>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final title = item['title'];
        if (title is String && !title.startsWith('Community:')) {
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
      // 清洗：去编辑链接/面包屑、剥 float/width 内联样式、复杂表格转段落。
      html: sanitizeWikiHtml(text is String ? text : ''),
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
