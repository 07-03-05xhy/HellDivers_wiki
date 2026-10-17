import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';

/// 收藏页：列表 + 左滑删除。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<FavoriteEntry>? _entries;
  Object? _error;

  WikiRepository get _repo => context.read<WikiRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<FavoriteEntry> entries = await _repo.favorites();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e);
    }
  }

  Future<void> _remove(FavoriteEntry entry) async {
    setState(() => _entries?.remove(entry));
    await _repo.removeFavorite(entry.pageId);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已取消收藏「${entry.title}」')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return HdErrorView(message: '加载失败：$_error', onRetry: _load);
    }
    final List<FavoriteEntry>? entries = _entries;
    if (entries == null) {
      return const HdLoadingView();
    }
    if (entries.isEmpty) {
      return const Center(
        child: Text('暂无收藏', style: TextStyle(color: HdColors.dimGrey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final FavoriteEntry entry = entries[index];
        return Dismissible(
          key: ValueKey<int>(entry.pageId),
          direction: DismissDirection.endToStart,
          background: Container(
            color: HdColors.alertRed,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: HdColors.textPrimary),
          ),
          onDismissed: (_) => _remove(entry),
          child: HdPanelCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => ArticlePage(title: entry.title)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.star,
                    color: HdColors.helldiverYellow, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
