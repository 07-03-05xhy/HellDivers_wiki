import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/category_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

void main() {
  testWidgets('分类页展示成员列表', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..members = <WikiPageSummary>[
        const WikiPageSummary(pageId: 1, title: 'AR-23 解放者'),
      ];
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: buildHdTheme(),
        home: const CategoryPage(
          category: WikiCategory(title: 'Category:Weapons', pages: 42),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Weapons'), findsOneWidget);
    expect(find.text('AR-23 解放者'), findsOneWidget);
  });
}
