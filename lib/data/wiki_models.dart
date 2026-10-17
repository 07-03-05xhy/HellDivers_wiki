/// 绝地潜兵2中文Wiki 数据模型与常量。
///
/// 数据源: https://helldivers.wiki.gg/zh/api.php (MediaWiki 1.43.6)
library;

/// API 入口（GET + JSON）。
const String kWikiApiBase = 'https://helldivers.wiki.gg/zh/api.php';

/// 站点根，用于拼接 /zh/wiki/<标题> 条目链接。
const String kWikiSiteBase = 'https://helldivers.wiki.gg/zh';

/// 文件快捷路径，后接 URL 编码的文件名，可用 ?width= 取缩略图。
const String kWikiFilePath = 'https://helldivers.wiki.gg/zh/Special:FilePath/';

/// 请求标识（wiki.gg 要求客户端带可识别的 UA）。
const String kWikiUserAgent = 'HelldiversWikiApp/0.1 (Flutter; zh-wiki-reader)';

/// 列表条目摘要（搜索 / 分类成员共用）。
class WikiPageSummary {
  const WikiPageSummary({
    required this.pageId,
    required this.title,
    this.snippet = '',
    this.thumbnailUrl,
  });

  final int pageId;
  final String title;

  /// 搜索命中摘要（可能含 HTML 高亮标记 <span class="searchmatch">）。
  final String snippet;

  /// 题图缩略图 URL，可能为空。
  final String? thumbnailUrl;
}

/// 条目章节（目录用）。
class WikiSection {
  const WikiSection({
    required this.index,
    required this.anchor,
    required this.line,
    required this.level,
  });

  final int index;
  final String anchor;
  final String line;
  final int level;
}

/// 完整条目（正文为 MediaWiki 渲染后的 HTML）。
class WikiArticle {
  const WikiArticle({
    required this.pageId,
    required this.title,
    required this.displayTitle,
    required this.html,
    required this.sections,
    required this.fetchedAt,
  });

  final int pageId;
  final String title;

  /// 纯文本展示标题（已剥离 HTML 标签）。
  final String displayTitle;

  /// action=parse 返回的渲染 HTML。
  final String html;
  final List<WikiSection> sections;
  final DateTime fetchedAt;
}

/// 分类条目（含成员数）。
class WikiCategory {
  const WikiCategory({required this.title, required this.pages});

  /// 形如 "Category:武器" 的完整标题。
  final String title;
  final int pages;

  /// 去掉 "Category:" 前缀的短名。
  String get shortName =>
      title.startsWith('Category:') ? title.substring(9) : title;
}

/// 收藏夹条目。
class FavoriteEntry {
  const FavoriteEntry({
    required this.pageId,
    required this.title,
    required this.addedAt,
  });

  final int pageId;
  final String title;
  final DateTime addedAt;
}

/// 浏览历史条目。
class HistoryEntry {
  const HistoryEntry({
    required this.pageId,
    required this.title,
    required this.visitedAt,
  });

  final int pageId;
  final String title;
  final DateTime visitedAt;
}
