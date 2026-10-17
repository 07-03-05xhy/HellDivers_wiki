import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_html_sanitizer.dart';
import 'package:helldivers_wiki/data/wiki_models.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/ui/pages/article_page.dart';
import 'package:provider/provider.dart';

import 'fake_wiki_repository.dart';

/// 用真实 "40-K 热熔枪" 同款问题 HTML（浮动盒 + 编辑链接 + 复杂表格）
/// 验证 ArticlePage：不溢出、无编辑链接、表格数据可读。
void main() {
  testWidgets('ArticlePage 渲染清洗后的真实问题 HTML', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));

    const String raw = '<div class="mw-content-ltr mw-parser-output">'
        '<table style="padding-bottom:5px"><tbody><tr><td>'
        '<i>这篇文章是关于支援武器的。</i></td></tr></tbody></table>'
        '<div class="noexcerpt" style="border:1px solid #333; width:70%; '
        'max-width:250px; float:right; text-align:center;">'
        'Last updated: <b>1.007.000</b><br /> Current patch: <b>1.007.100</b></div>'
        '<p><b>40-K 热熔枪</b>是一把支援武器，高温射流可熔化重甲。</p>'
        '<h2><span class="mw-headline">战略配备数据</span>'
        '<span class="mw-editsection">[<a href="/e1">编辑</a> | '
        '<a href="/e2">编辑源代码</a>]</span></h2>'
        '<table class="wikitable"><tbody>'
        '<tr><th colspan="3"><b>通用</b></th></tr>'
        '<tr><th rowspan="2" width="25%">呼叫时间</th><td>3 秒</td><td>备注</td></tr>'
        '<tr><td>有延迟</td><td>-</td></tr>'
        '<tr><th>伤害</th><td>2000</td><td>穿甲</td></tr>'
        '</tbody></table>'
        '<h2><span class="mw-headline">战术信息</span></h2>'
        '<ul><li>近距离伤害极高</li><li>对重甲目标有效</li></ul>'
        '</div>';

    final FakeWikiRepository repo = FakeWikiRepository();
    repo.articles['40-K 热熔枪'] = WikiArticle(
      pageId: 1,
      title: '40-K 热熔枪',
      displayTitle: '40-K 热熔枪',
      html: sanitizeWikiHtml(raw),
      sections: const <WikiSection>[
        WikiSection(index: 1, anchor: 'a', line: '战略配备数据', level: 2),
        WikiSection(index: 2, anchor: 'b', line: '战术信息', level: 2),
      ],
      fetchedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      Provider<WikiRepository>.value(
        value: repo,
        child: const MaterialApp(home: ArticlePage(title: '40-K 热熔枪')),
      ),
    );
    await tester.pumpAndSettle();

    // 内容断言：表格数据在、编辑链接不在、无渲染异常（溢出会让 takeException 非空）。
    expect(find.textContaining('呼叫时间'), findsWidgets);
    expect(find.textContaining('3 秒'), findsWidgets);
    expect(find.textContaining('2000'), findsWidgets);
    expect(find.textContaining('编辑源代码'), findsNothing);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(ArticlePage),
      matchesGoldenFile('goldens/article_render.png'),
    );
  });
}
