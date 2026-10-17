import 'package:flutter_test/flutter_test.dart';
import 'package:helldivers_wiki/data/local_store.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

void main() {
  late LocalStore store;

  setUp(() {
    store = LocalStore(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await store.close();
  });

  group('收藏', () {
    test('添加、查询、移除', () async {
      expect(await store.favorites(), isEmpty);
      await store.addFavorite(1, '解放者');
      await store.addFavorite(2, '飞鹰');
      expect(await store.isFavorite(1), isTrue);
      expect(await store.isFavorite(3), isFalse);

      final favs = await store.favorites();
      expect(favs, hasLength(2));
      // 按 addedAt 倒序：后添加的在前。
      expect(favs.first.pageId, 2);
      expect(favs.map((f) => f.title), containsAll(['解放者', '飞鹰']));

      await store.removeFavorite(1);
      expect(await store.isFavorite(1), isFalse);
      expect(await store.favorites(), hasLength(1));
    });

    test('重复收藏覆盖且不产生重复行', () async {
      await store.addFavorite(1, '解放者');
      await store.addFavorite(1, '解放者改');
      final favs = await store.favorites();
      expect(favs, hasLength(1));
      expect(favs.single.title, '解放者改');
    });
  });

  group('历史', () {
    test('重访更新 visitedAt 并置顶（去重）', () async {
      await store.recordVisit(1, 'A');
      await store.recordVisit(2, 'B');
      await store.recordVisit(1, 'A');
      final history = await store.history();
      expect(history, hasLength(2));
      expect(history.first.pageId, 1); // 重访后置顶
    });

    test('上限裁剪到 100 条', () async {
      for (var i = 1; i <= 120; i++) {
        await store.recordVisit(i, '页面$i');
      }
      final history = await store.history(limit: 200);
      expect(history, hasLength(100));
      expect(history.first.pageId, 120); // 最新在前
      expect(history.last.pageId, 21); // 最旧的 20 条被裁掉
    });

    test('clearHistory 清空', () async {
      await store.recordVisit(1, 'A');
      await store.clearHistory();
      expect(await store.history(), isEmpty);
    });

    test('limit 参数生效', () async {
      for (var i = 1; i <= 5; i++) {
        await store.recordVisit(i, '页面$i');
      }
      final history = await store.history(limit: 3);
      expect(history, hasLength(3));
      expect(history.first.pageId, 5);
    });
  });
}
