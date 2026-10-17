import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

/// 分类成员列表页：游标分页加载。
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.category});

  final WikiCategory category;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final ScrollController _scrollController = ScrollController();
  final List<WikiPageSummary> _items = <WikiPageSummary>[];
  final Map<String, String> _thumbnails = <String, String>{};

  String? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loading) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ({List<WikiPageSummary> items, String? cursor}) result =
          await _repo.categoryMembers(widget.category.title,
              cursor: _cursor);
      final List<String> titles =
          result.items.map((WikiPageSummary e) => e.title).toList();
      final Map<String, String> thumbs =
          titles.isEmpty ? <String, String>{} : await _repo.pageImages(titles);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(result.items);
        _thumbnails.addAll(thumbs);
        _cursor = result.cursor;
        _hasMore = result.cursor != null;
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

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _thumbnails.clear();
      _cursor = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.shortName),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty && _loading) {
      return const HdLoadingView();
    }
    if (_items.isEmpty && _error != null) {
      return HdErrorView(message: '加载失败：$_error', onRetry: _loadMore);
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('该分类暂无条目', style: TextStyle(color: HdColors.dimGrey)),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final WikiPageSummary item = _items[index];
          final String? thumb = _thumbnails[item.title];
          return HdPanelCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArticlePage(title: item.title),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (thumb != null)
                  CachedNetworkImage(
                    imageUrl: thumb,
                    httpHeaders: const <String, String>{
                      'User-Agent': kWikiUserAgent,
                    },
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const SizedBox(width: 64, height: 64),
                  )
                else
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.article_outlined,
                        color: HdColors.lineGrey),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.chevron_right, color: HdColors.dimGrey),
              ],
            ),
          );
        },
      ),
    );
  }
}
