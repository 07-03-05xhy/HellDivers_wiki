import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';

/// 喂假数据的 WikiRepository 实现，仅供 UI 冒烟测试使用。
class FakeWikiRepository implements WikiRepository {
  List<WikiCategory> categories = <WikiCategory>[];
  List<WikiPageSummary> members = <WikiPageSummary>[];
  List<WikiPageSummary> searchResults = <WikiPageSummary>[];
  Map<String, WikiArticle> articles = <String, WikiArticle>{};
  List<FavoriteEntry> favoriteList = <FavoriteEntry>[];
  List<HistoryEntry> historyList = <HistoryEntry>[];
  Map<String, String> images = <String, String>{};

  int recordVisitCount = 0;
  int clearHistoryCount = 0;

  @override
  Future<List<WikiCategory>> topCategories({int limit = 50}) async =>
      categories;

  @override
  Future<({List<WikiPageSummary> items, String? cursor})> categoryMembers(
    String category, {
    String? cursor,
    int limit = 50,
  }) async =>
      (items: members, cursor: null);

  @override
  Future<List<WikiPageSummary>> search(String query,
      {int limit = 20}) async =>
      searchResults;

  @override
  Future<WikiArticle> article(String title) async {
    final WikiArticle? cached = articles[title];
    if (cached != null) {
      return cached;
    }
    return WikiArticle(
      pageId: 1,
      title: title,
      displayTitle: title,
      html: '<h1>$title</h1><p>测试正文</p>',
      sections: const <WikiSection>[
        WikiSection(index: 1, anchor: 'intro', line: '简介', level: 2),
      ],
      fetchedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<String?> pageImage(String title, {int width = 320}) async =>
      images[title];

  @override
  Future<Map<String, String>> pageImages(List<String> titles,
      {int width = 320}) async {
    final Map<String, String> result = <String, String>{};
    for (final String title in titles) {
      final String? url = images[title];
      if (url != null) {
        result[title] = url;
      }
    }
    return result;
  }

  @override
  Future<List<FavoriteEntry>> favorites() async => favoriteList;

  @override
  Future<void> addFavorite(int pageId, String title) async {
    favoriteList.add(FavoriteEntry(
        pageId: pageId, title: title, addedAt: DateTime(2026, 1, 1)));
  }

  @override
  Future<void> removeFavorite(int pageId) async {
    favoriteList.removeWhere((FavoriteEntry e) => e.pageId == pageId);
  }

  @override
  Future<bool> isFavorite(int pageId) async =>
      favoriteList.any((FavoriteEntry e) => e.pageId == pageId);

  @override
  Future<List<HistoryEntry>> history({int limit = 100}) async =>
      historyList;

  @override
  Future<void> recordVisit(int pageId, String title) async {
    recordVisitCount++;
    historyList.insert(
        0,
        HistoryEntry(
            pageId: pageId, title: title, visitedAt: DateTime(2026, 1, 1)));
  }

  @override
  Future<void> clearHistory() async {
    clearHistoryCount++;
    historyList.clear();
  }

  @override
  void close() {}
}
