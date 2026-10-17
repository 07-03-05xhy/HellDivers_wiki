import 'wiki_models.dart';

/// 数据层对外契约。UI 层只依赖此接口，不直接触碰 API 客户端或 SQLite。
///
/// 实现: lib/data/wiki_repository_impl.dart（data-dev 负责）。
abstract class WikiRepository {
  /// 全站分类列表（按成员数降序由实现层排序），[limit] 默认 50。
  Future<List<WikiCategory>> topCategories({int limit = 50});

  /// 某分类下的条目分页。[category] 传完整名（"Category:武器"）。
  /// 返回结果与下一页游标；无更多时 cursor 为 null。
  Future<({List<WikiPageSummary> items, String? cursor})> categoryMembers(
    String category, {
    String? cursor,
    int limit = 50,
  });

  /// 全文搜索。
  Future<List<WikiPageSummary>> search(String query, {int limit = 20});

  /// 获取完整条目（含渲染 HTML 与章节目录）。
  Future<WikiArticle> article(String title);

  /// 条目题图 URL（[width] 为期望缩略宽度），无题图返回 null。
  Future<String?> pageImage(String title, {int width = 320});

  /// 批量获取题图（列表页用），key 为条目标题。
  Future<Map<String, String>> pageImages(List<String> titles,
      {int width = 320});

  // ---- 收藏 ----
  Future<List<FavoriteEntry>> favorites();
  Future<void> addFavorite(int pageId, String title);
  Future<void> removeFavorite(int pageId);
  Future<bool> isFavorite(int pageId);

  // ---- 历史 ----
  Future<List<HistoryEntry>> history({int limit = 100});
  Future<void> recordVisit(int pageId, String title);
  Future<void> clearHistory();

  /// 释放底层资源（数据库连接 / HTTP 客户端）。应用销毁时调用一次。
  void close();
}
