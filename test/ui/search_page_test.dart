import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/search_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

void main() {
  testWidgets('搜索页输入后防抖并展示结果', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..searchResults = <WikiPageSummary>[
        const WikiPageSummary(
          pageId: 3,
          title: '解放者',
          snippet:
              '解放者是<span class="searchmatch">突击步枪</span>。',
        ),
      ];
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child:
          MaterialApp(theme: buildHdTheme(), home: const SearchPage()),
    ));
    expect(find.text('输入关键词开始搜索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '解放者');
    // 防抖 400ms。
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('解放者'), findsWidgets);
  });

  testWidgets('搜索无结果时显示占位文案', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository();
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child:
          MaterialApp(theme: buildHdTheme(), home: const SearchPage()),
    ));
    await tester.enterText(find.byType(TextField), '不存在的条目');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('未找到相关条目'), findsOneWidget);
  });
}
