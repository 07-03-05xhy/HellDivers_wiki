import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/favorites_page.dart';
import 'package:helldivers_wiki/ui/pages/history_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

Widget _wrap(Widget child, FakeWikiRepository repo) {
  return Provider<WikiRepository>.value(
    value: repo,
    child: MaterialApp(theme: buildHdTheme(), home: child),
  );
}

void main() {
  testWidgets('收藏页展示列表，左滑删除', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..favoriteList = <FavoriteEntry>[
        FavoriteEntry(
            pageId: 1, title: '解放者', addedAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(const FavoritesPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('解放者'), findsOneWidget);

    await tester.drag(find.text('解放者'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('解放者'), findsNothing);
    expect(repo.favoriteList, isEmpty);
    expect(find.text('暂无收藏'), findsOneWidget);
  });

  testWidgets('历史页展示列表并可清空', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..historyList = <HistoryEntry>[
        HistoryEntry(
            pageId: 1, title: '终结族', visitedAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(const HistoryPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('终结族'), findsOneWidget);

    await tester.tap(find.byTooltip('清空历史'));
    await tester.pumpAndSettle();
    expect(find.text('确定要清空全部浏览记录吗？'), findsOneWidget);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(repo.clearHistoryCount, 1);
    expect(find.text('暂无浏览记录'), findsOneWidget);
  });

  testWidgets('空收藏页显示占位文案', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository();
    await tester.pumpWidget(_wrap(const FavoritesPage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('暂无收藏'), findsOneWidget);
  });
}
