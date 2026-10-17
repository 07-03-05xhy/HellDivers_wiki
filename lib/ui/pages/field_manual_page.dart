import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

class _ManualTab {
  const _ManualTab(this.label, this.category, this.keyword);

  final String label;
  final String category;
  final String keyword;
}

/// 图鉴专项视图：预置分类映射 + TabBar 卡片网格。
class FieldManualPage extends StatelessWidget {
  const FieldManualPage({super.key});

  static const List<_ManualTab> _tabs = <_ManualTab>[
    _ManualTab('武器', 'Category:Weapons', 'Weapons'),
    _ManualTab('战备', 'Category:Stratagems', 'Stratagems'),
    _ManualTab('敌人', 'Category:Enemies', 'Enemies'),
    _ManualTab('护甲', 'Category:Armor', 'Armor'),
    _ManualTab('任务', 'Category:Missions', 'Missions'),
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<WikiPageSummary> items =
          (await _repo.categoryMembers(widget.tab.category)).items;
      // 分类无结果时回退到关键词搜索。
      if (items.isEmpty) {
        items = await _repo.search(widget.tab.keyword);
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
