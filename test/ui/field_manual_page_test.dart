import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/theme/hd_theme.dart';
import 'package:helldivers_wiki/ui/pages/field_manual_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

void main() {
  testWidgets('图鉴页展示 Tab 与分类条目网格', (WidgetTester tester) async {
    final FakeWikiRepository repo = FakeWikiRepository()
      ..members = <WikiPageSummary>[
        const WikiPageSummary(pageId: 1, title: 'AR-23 解放者'),
        const WikiPageSummary(pageId: 2, title: 'SG-8 制裁者'),
      ];
    await tester.pumpWidget(Provider<WikiRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: buildHdTheme(),
        home: const FieldManualPage(),
      ),
    ));
    await tester.pumpAndSettle();

    for (final String label in <String>['武器', '战备', '敌人', '护甲', '任务']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('AR-23 解放者'), findsOneWidget);
    expect(find.text('SG-8 制裁者'), findsOneWidget);
  });
}
