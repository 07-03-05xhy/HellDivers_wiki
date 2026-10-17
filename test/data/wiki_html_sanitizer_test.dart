import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/wiki_html_sanitizer.dart';

void main() {
  group('WikiHtmlSanitizer', () {
    test('删除编辑链接与面包屑', () {
      final String out = sanitizeWikiHtml(
        '<h2><span class="mw-headline">获取方式</span>'
        '<span class="mw-editsection">'
        '<span class="mw-editsection-bracket">[</span>'
        '<a href="/edit">编辑</a> | <a href="/edit2">编辑源代码</a>'
        '<span class="mw-editsection-bracket">]</span></span></h2>'
        '<div class="breadcrumb noexcerpt">'
        '<div class="breadcrumb-item">战略配备</div></div>'
        '<p>正文内容</p>',
      );
      expect(out, contains('获取方式'));
      expect(out, contains('正文内容'));
      expect(out, isNot(contains('mw-editsection')));
      expect(out, isNot(contains('编辑源代码')));
      expect(out, isNot(contains('breadcrumb')));
    });

    test('剥离 float/width 内联样式，display:none 元素整体删除', () {
      final String out = sanitizeWikiHtml(
        '<div class="noexcerpt" style="float: right; width: 70%;">'
        'Last updated: <b>1.007.000</b></div>'
        '<span class="noexcerpt" style="display:none">隐藏</span>'
        '<span style="display: none">也隐藏</span>'
        '<p style="color:red">可见</p>',
      );
      expect(out, contains('Last updated'));
      expect(out, contains('可见'));
      expect(out, isNot(contains('隐藏')));
      expect(out, isNot(contains('float')));
      expect(out, isNot(contains('style=')));
    });

    test('含 colspan/rowspan 的复杂表格转换为段落列表', () {
      final String out = sanitizeWikiHtml(
        '<table class="wikitable"><tbody>'
        '<tr><th colspan="2"><b>通用</b></th></tr>'
        '<tr><th rowspan="2" width="25%">呼叫时间</th><td>3 秒</td></tr>'
        '<tr><td>有延迟</td></tr>'
        '</tbody></table>',
      );
      expect(out, isNot(contains('<table')));
      expect(out, contains('通用'));
      expect(out, contains('呼叫时间'));
      expect(out, contains('3 秒'));
      expect(out, contains('有延迟'));
      expect(out, contains('<b>呼叫时间</b>'));
      // 宽度属性也要被清掉（转换后不应残留）
      expect(out, isNot(contains('rowspan')));
    });

    test('简单表格保留但剥离宽高属性', () {
      final String out = sanitizeWikiHtml(
        '<table class="wikitable" width="300"><tbody>'
        '<tr><th>日期</th><th>变更</th></tr>'
        '<tr><td width="100">1.007</td><td>加强</td></tr>'
        '</tbody></table>',
      );
      expect(out, contains('<table'));
      expect(out, contains('1.007'));
      expect(out, isNot(contains('width=')));
    });

    test('删除 JS 注水占位空 div，保留含媒体的 div', () {
      final String out = sanitizeWikiHtml(
        '<div class="druid-toggleable-data druid-toggleable-data-empty" '
        'data-druid="1-2"></div>'
        '<div class="thumb"><img src="https://x/a.png" /></div>'
        '<p>文字</p>',
      );
      expect(out, isNot(contains('druid-toggleable-data-empty')));
      expect(out, contains('a.png'));
      expect(out, contains('文字'));
    });

    test('单元格文本中的特殊字符被转义', () {
      final String out = sanitizeWikiHtml(
        '<table><tbody><tr><th rowspan="2">A&B</th><td>x</td></tr>'
        '<tr><td>y</td></tr></tbody></table>',
      );
      expect(out, contains('A&amp;B'));
    });
  });
}
