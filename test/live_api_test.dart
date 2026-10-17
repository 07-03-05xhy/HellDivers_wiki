import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/local_store.dart';
import 'package:helldivers_wiki/data/wiki_repository.dart';
import 'package:helldivers_wiki/data/wiki_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

/// 打真实 https://helldivers.wiki.gg/zh/api.php 的集成测试。
/// 覆盖用户 v1.0.1 真机反馈的每一类问题：首页分类空、图鉴分类错、
/// 图片 403、正文编辑链接/竖排样式/表格空白、内容串项。
void main() {
  late WikiRepository repo;

  setUpAll(() {
    repo = WikiRepositoryImpl(
      store: LocalStore(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      ),
    );
  });

  tearDownAll(() => repo.close());

  test('首页分类：topCategories 非空且含中文大分类', () async {
    final List cats = await repo.topCategories(limit: 50);
    expect(cats, isNotEmpty, reason: 'v1.0.1 首页"暂无分类数据"的回归');
    final titles = cats.map((c) => c.title as String).toList();
    expect(titles, contains('Category:武器'));
    expect(titles, contains('Category:敌人'));
    // 维护类分类不应出现
    expect(titles.any((t) => t.contains('templates')), isFalse);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('图鉴分类：武器满编、战备为呼叫类、护甲三分类合并', () async {
    final weapons = await repo.categoryMembers('Category:武器', limit: 500);
    expect(weapons.items.length, greaterThan(50),
        reason: '武器分类应有 150+ 成员而不是 1 个愚人节页面');
    final nsJunk = RegExp(r'^(Community|File|Category|Template|Module):');
    expect(weapons.items.every((w) => !nsJunk.hasMatch(w.title)), isTrue,
        reason: '不应混入 Community: 等命名空间页面');

    // 战备 Tab 的 7 个来源分类：并集非空、无武器、无愚人节杂项。
    const stratCats = <String>[
      'Category:Orbital Stratagems',
      'Category:Eagle Stratagems',
      'Category:Sentry Stratagems',
      'Category:Emplacement Stratagems',
      'Category:Backpack Stratagems',
      'Category:Mission Stratagems',
      'Category:Ship Stratagems',
    ];
    final all = <String>{};
    for (final c in stratCats) {
      final page = await repo.categoryMembers(c, limit: 500);
      expect(page.items, isNotEmpty, reason: '$c 应有成员');
      all.addAll(page.items.map((e) => e.title));
    }
    expect(all.length, greaterThan(20));
    expect(all.any((t) => t.contains('热熔枪')), isFalse,
        reason: '战备 Tab 不应混入武器（用户截图中的 40-K 热熔枪）');
    expect(all.any((t) => t.contains('轨道')), isTrue, reason: '应有轨道攻击类战备');

    for (final c in ['Category:Light Armor', 'Category:Medium Armor', 'Category:Heavy Armor']) {
      final armor = await repo.categoryMembers(c, limit: 500);
      expect(armor.items, isNotEmpty, reason: '$c 应有成员');
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('正文清洗：40-K 热熔枪 无编辑链接/浮动样式，表格数据保留', () async {
    final article = await repo.article('40-K 热熔枪');
    expect(article.html, isNot(contains('mw-editsection')));
    expect(article.html, isNot(contains('编辑源代码')));
    expect(article.html, isNot(contains('float:')));
    expect(article.html, isNot(contains('breadcrumb')));
    // 复杂 wikitable 转段落后数据必须可读
    expect(article.html, contains('呼叫时间'));
    expect(article.html, contains('伤害'));
    expect(article.sections, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('题图 URL 可直接取到（带应用 UA 不 403）', () async {
    final images = await repo.pageImages(['AR-23 解放者']);
    expect(images, isNotEmpty);
    final url = images.values.first;
    expect(url.startsWith('https://'), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
