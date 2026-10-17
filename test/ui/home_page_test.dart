import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/home_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

Widget _wrap(Widget child, FakeWikiRepository repo) {
  return Provider<WikiRepository>.value(
    value: repo,
    child: MaterialApp(theme: buildHdTheme(), home: child),
  );
}

void main() {
  testWidgets('首页显示标题栏、搜索入口、分类网格与最近浏览',
      (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..categories = <WikiCategory>[
        const WikiCategory(title: 'Category:Weapons', pages: 42),
        const WikiCategory(title: 'Category:Enemies', pages: 30),
      ]
      ..historyList = <HistoryEntry>[
        HistoryEntry(
            pageId: 7,
            title: '解放者突击步枪',
            visitedAt: DateTime(2026, 1, 1)),
      ];
    await tester.pumpWidget(_wrap(const HomePage(), repo));
    await tester.pumpAndSettle();

    expect(find.text('绝地潜兵2 WIKI'), findsOneWidget);
    expect(find.text('SUPER EARTH TERMINAL'), findsOneWidget);
    expect(find.text('分类索引'), findsOneWidget);
    expect(find.text('Weapons'), findsOneWidget);
    expect(find.text('Enemies'), findsOneWidget);
    expect(find.text('最近浏览'), findsOneWidget);
    expect(find.text('解放者突击步枪'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('首页空历史显示占位文案', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository();
    await tester.pumpWidget(_wrap(const HomePage(), repo));
    await tester.pumpAndSettle();
    expect(find.text('暂无浏览记录'), findsOneWidget);
  });
}
