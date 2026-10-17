import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// MediaWiki action=parse 输出的 HTML 清洗器。
///
/// 真实条目（如 "40-K 热熔枪"）的 HTML 在 flutter_html 下有三大问题：
/// 1. 带 `float:right; width:70%; max-width:250px` 内联样式的盒子被挤成
///    竖排单字流 —— 全局剥离 style 属性解决；
/// 2. `[编辑 | 编辑源代码]` 等编辑链接噪声（.mw-editsection）、面包屑导航
///    （.breadcrumb）—— 直接删除；
/// 3. 含 colspan/rowspan 的复杂 wikitable 无法布局导致整段空白 ——
///    转换为逐行段落列表。
///
/// 另外清理 JS 注水占位空 div（druid-* / display:none）。
class WikiHtmlSanitizer {
  WikiHtmlSanitizer._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// 直接删除的噪声元素选择器。
  static const List<String> _noiseSelectors = <String>[
    '.mw-editsection',
    '.breadcrumb',
    '.mw-indicators',
    '.navbox',
    'style',
    'script',
    'link',
  ];

  /// 清洗 [rawHtml]，返回可安全交给 flutter_html 渲染的 HTML。
  static String sanitize(String rawHtml) {
    final dom.Document doc = html_parser.parse(rawHtml);

    // 1. 删除噪声元素。
    for (final String selector in _noiseSelectors) {
      for (final dom.Element e in doc.querySelectorAll(selector).toList()) {
        e.remove();
      }
    }

    // 2. 处理内联样式：display:none 的元素整体删除，其余剥离 style。
    for (final dom.Element e in doc.querySelectorAll('[style]').toList()) {
      final String compact = (e.attributes['style'] ?? '')
          .replaceAll(_whitespace, '')
          .toLowerCase();
      if (compact.contains('display:none')) {
        e.remove();
      } else {
        e.attributes.remove('style');
      }
    }

    // 3. 删除无文本、无媒体的空 div（JS 注水占位，如 druid-toggleable-data-empty）。
    for (final dom.Element e in doc.querySelectorAll('div').toList()) {
      if (e.text.trim().isEmpty &&
          e.querySelector('img, table, ul, ol, video, audio, svg') == null) {
        e.remove();
      }
    }

    // 4. 表格：复杂表格转段落列表；保留的表格剥离宽高属性。
    for (final dom.Element table
        in doc.querySelectorAll('table').toList()) {
      _processTable(table);
    }

    return doc.body?.innerHtml ?? rawHtml;
  }

  static void _processTable(dom.Element table) {
    final List<dom.Element> cells = table.querySelectorAll('th, td');
    final bool complex = cells.any((dom.Element c) =>
        c.attributes.containsKey('colspan') ||
        c.attributes.containsKey('rowspan'));

    if (!complex) {
      table.attributes.remove('width');
      for (final dom.Element c in cells) {
        c.attributes.remove('width');
        c.attributes.remove('height');
      }
      return;
    }

    // 复杂表格 -> 逐行段落：th 加粗，单元格以 ' · ' 连接。
    final StringBuffer buf = StringBuffer('<div class="table-as-list">');
    for (final dom.Element tr in table.querySelectorAll('tr')) {
      final List<dom.Element> rowCells = tr.children
          .where((dom.Element c) =>
              c.localName == 'th' || c.localName == 'td')
          .toList();
      if (rowCells.isEmpty) continue;
      final List<String> parts = <String>[];
      for (final dom.Element cell in rowCells) {
        final String text =
            cell.text.replaceAll(_whitespace, ' ').trim();
        if (text.isEmpty) continue;
        parts.add(cell.localName == 'th'
            ? '<b>' + _escape(text) + '</b>'
            : _escape(text));
      }
      if (parts.isNotEmpty) {
        buf.write('<p>' + parts.join(' \u00b7 ') + '</p>');
      }
    }
    buf.write('</div>');

    final dom.Element replacement = dom.Element.tag('div');
    replacement.append(html_parser.parseFragment(buf.toString()));
    table.replaceWith(replacement);
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// 便捷函数：等价于 [WikiHtmlSanitizer.sanitize]。
String sanitizeWikiHtml(String rawHtml) => WikiHtmlSanitizer.sanitize(rawHtml);
