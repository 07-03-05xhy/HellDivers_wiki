import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

/// 图鉴 Tab 配置：中文分类名为准（实测 zh 站的英文分类是空壳/杂项，
/// 如 Category:Weapons 里只有一个愚人节社区页面）。
class _ManualTab {
  const _ManualTab(
    this.label, {
    required this.categories,
    this.excludeTitles = const <String>{},
    required this.keyword,
  });

  /// Tab 显示名。
  final String label;

  /// 成员来源分类（可多个，结果并集）。
  final List<String> categories;

  /// 按标题精确剔除的杂项页（分类同名枢纽页、元页面等）。
  final Set<String> excludeTitles;

  /// 分类为空时的搜索回退关键词。
  final String keyword;
}

/// 图鉴专项视图：预置分类映射 + TabBar 卡片网格。
class FieldManualPage extends StatelessWidget {
  const FieldManualPage({super.key});

  static const List<_ManualTab> _tabs = <_ManualTab>[
    _ManualTab(
      '武器',
      categories: <String>['Category:武器'],
      excludeTitles: <String>{'武器', 'Damage Comparison'},
      keyword: '武器',
    ),
    _ManualTab(
      '战备',
      // zh 站的 Category:战略配备 全是支援武器（=武器子集），真正的呼叫类
      // 战备在这批英文分类下（成员页都是中文标题）。
      categories: <String>[
        'Category:Orbital Stratagems',
        'Category:Eagle Stratagems',
        'Category:Sentry Stratagems',
        'Category:Emplacement Stratagems',
        'Category:Backpack Stratagems',
        'Category:Mission Stratagems',
        'Category:Ship Stratagems',
      ],
      excludeTitles: <String>{'April Fools/Budget Helldiver'},
      keyword: '轨道',
    ),
    _ManualTab(
      '敌人',
      categories: <String>['Category:敌人'],
      excludeTitles: <String>{'敌人', '阵营'},
      keyword: '敌人',
    ),
    _ManualTab(
      '护甲',
      categories: <String>[
        'Category:Light Armor',
        'Category:Medium Armor',
        'Category:Heavy Armor',
      ],
      keyword: '护甲',
    ),
    _ManualTab(
      '任务',
      categories: <String>['Category:Missions'],
      excludeTitles: <String>{
        'Difficulty',
        'Levels',
        'Personal Orders',
        '效果',
        '等级',
      },
      keyword: '任务',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('图鉴'),
          bottom: TabBar(
            labelColor: HdColors.helldiverYellow,
            unselectedLabelColor: HdColors.dimGrey,
            indicatorColor: HdColors.helldiverYellow,
            tabs: <Widget>[
              for (final _ManualTab tab in _tabs) Tab(text: tab.label),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            for (final _ManualTab tab in _tabs) _ManualTabView(tab: tab),
          ],
        ),
      ),
    );
  }
}

class _ManualTabView extends StatefulWidget {
  const _ManualTabView({required this.tab});

  final _ManualTab tab;

  @override
  State<_ManualTabView> createState() => _ManualTabViewState();
}

class _ManualTabViewState extends State<_ManualTabView>
    with AutomaticKeepAliveClientMixin {
  /// 单分类翻页拉取的安全上限（武器分类约 151 条）。
  static const int _maxMembers = 600;

  List<WikiPageSummary> _items = <WikiPageSummary>[];
  Map<String, String> _thumbnails = <String, String>{};
  bool _loading = true;
  Object? _error;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 已知命名空间前缀（主命名空间里的标题可能含英文冒号，不能一刀切）。
  static final RegExp _namespacePrefix = RegExp(
    r'^(Community|File|Category|Template|Module|Special|Help|User|MediaWiki|Talk):',
  );

  bool _isJunkTitle(String title) =>
      _namespacePrefix.hasMatch(title) ||
      widget.tab.excludeTitles.contains(title);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1. 并集拉取所有来源分类。
      final List<WikiPageSummary> items = <WikiPageSummary>[];
      final Set<String> seen = <String>{};
      for (final String category in widget.tab.categories) {
        String? cursor;
        do {
          final ({List<WikiPageSummary> items, String? cursor}) page =
              await _repo.categoryMembers(category, cursor: cursor, limit: 500);
          for (final WikiPageSummary item in page.items) {
            if (seen.add(item.title)) items.add(item);
          }
          cursor = page.cursor;
        } while (cursor != null && seen.length < _maxMembers);
      }

      // 2. 剔除杂项标题（伪命名空间、愚人节整活、枢纽页）。
      items.removeWhere((WikiPageSummary e) => _isJunkTitle(e.title));

      // 3. 分类无结果时回退到关键词搜索（同样过滤杂项）。
      if (items.isEmpty) {
        final List<WikiPageSummary> results =
            await _repo.search(widget.tab.keyword, limit: 50);
        items.addAll(results.where((WikiPageSummary e) =>
            !_isJunkTitle(e.title) && seen.add(e.title)));
      }

      final Map<String, String> thumbs = items.isEmpty
          ? <String, String>{}
          : await _repo.pageImages(
              items.map((WikiPageSummary e) => e.title).toList());
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _thumbnails = thumbs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const HdLoadingView();
    }
    if (_error != null) {
      return HdErrorView(message: '加载失败：$_error', onRetry: _load);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('暂无图鉴数据', style: TextStyle(color: HdColors.dimGrey)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final WikiPageSummary item = _items[index];
        final String? thumb =
            item.thumbnailUrl ?? _thumbnails[item.title];
        return HdPanelCard(
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => ArticlePage(title: item.title)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: thumb != null
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        httpHeaders: const <String, String>{
                          'User-Agent': kWikiUserAgent,
                        },
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: HdColors.lineGrey,
                          size: 36,
                        ),
                      )
                    : const Icon(Icons.image_not_supported_outlined,
                        color: HdColors.lineGrey, size: 36),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
