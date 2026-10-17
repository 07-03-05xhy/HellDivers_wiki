import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/article_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

void main() {
  testWidgets('条目页渲染正文并记录浏览，收藏按钮可切换',
      (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository();
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: buildHdTheme(),
        home: const ArticlePage(title: '解放者'),
      ),
    ));
    await tester.pumpAndSettle();

    // 标题与正文渲染。
    expect(find.text('解放者'), findsWidgets);
    // 进入即记录历史。
    expect(repo.recordVisitCount, greaterThan(0));

    // 收藏切换。
    expect(find.byTooltip('收藏'), findsOneWidget);
    await tester.tap(find.byTooltip('收藏'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(repo.favoriteList, hasLength(1));

    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();
    expect(repo.favoriteList, isEmpty);
  });

  testWidgets('条目页目录抽屉展示章节', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository();
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: buildHdTheme(),
        home: const ArticlePage(title: '解放者'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('目录'));
    await tester.pumpAndSettle();
    expect(find.text('目录'), findsWidgets);
    expect(find.text('简介'), findsOneWidget);
  });
}
