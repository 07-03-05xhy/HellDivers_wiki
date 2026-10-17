import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/wiki_models.dart';
import '../../data/wiki_repository.dart';
import '../../theme/hd_theme.dart';
import '../../theme/hd_widgets.dart';
import 'article_page.dart';
import 'category_page.dart';
import 'favorites_page.dart';
import 'field_manual_page.dart';
import 'history_page.dart';
import 'search_page.dart';

/// 应用首页：标题栏 + 搜索入口 + 分类网格 + 最近浏览。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final WikiRepository repo = context.read<WikiRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '绝地潜兵2 WIKI',
              style: TextStyle(
                color: HdColors.helldiverYellow,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              'SUPER EARTH TERMINAL',
              style: TextStyle(
                color: HdColors.dimGrey,
                fontSize: 10,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '图鉴',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const FieldManualPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: '收藏',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const FavoritesPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const HistoryPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          HdSearchBar(
            readOnly: true,
            hintText: '搜索绝地潜兵2 Wiki…',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
          ),
          const SizedBox(height: 24),
          const HdSectionHeader(title: '分类索引'),
          FutureBuilder<List<WikiCategory>>(
            future: repo.topCategories(),
            builder: (BuildContext context,
                AsyncSnapshot<List<WikiCategory>> snapshot) {
              if (snapshot.hasError) {
                return HdErrorView(
                  message: '分类加载失败：${snapshot.error}',
                  onRetry: () {},
                );
              }
              if (!snapshot.hasData) {
                return const HdLoadingView();
              }
              final List<WikiCategory> categories = snapshot.data!
                  .where((WikiCategory c) => c.pages > 0)
                  .take(12)
                  .toList();
              if (categories.isEmpty) {
                return const Text('暂无分类数据',
                    style: TextStyle(color: HdColors.dimGrey));
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                ),
                itemCount: categories.length,
                itemBuilder: (BuildContext context, int index) {
                  final WikiCategory category = categories[index];
                  return HdPanelCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CategoryPage(category: category),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          category.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HdColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${category.pages} 条目',
                          style: const TextStyle(
                            color: HdColors.dimGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const HdSectionHeader(title: '最近浏览'),
          FutureBuilder<List<HistoryEntry>>(
            future: repo.history(limit: 20),
            builder: (BuildContext context,
                AsyncSnapshot<List<HistoryEntry>> snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('暂无浏览记录',
                    style: TextStyle(color: HdColors.dimGrey));
              }
              final List<HistoryEntry> entries = snapshot.data!;
              return SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final HistoryEntry entry = entries[index];
                    return SizedBox(
                      width: 180,
                      child: HdPanelCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ArticlePage(title: entry.title),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.description_outlined,
                                color: HdColors.helldiverYellow, size: 18),
                            const SizedBox(height: 6),
                            Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
