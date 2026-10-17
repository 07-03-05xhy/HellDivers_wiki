import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'wiki_models.dart';

/// 基于 sqflite 的本地持久层：收藏夹与浏览历史。
///
/// 默认使用平台数据库；测试可注入 [databaseFactory]（如 sqflite_common_ffi）
/// 与内存路径。
class LocalStore {
  LocalStore({DatabaseFactory? factory, String? databasePath})
      : _factory = factory ?? databaseFactory,
        _databasePath = databasePath;

  static const int _historyLimit = 100;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final path = _databasePath ?? p.join(await _factory.getDatabasesPath(), 'wiki_store.db');
    final db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE favorites('
            'pageId INTEGER PRIMARY KEY, '
            'title TEXT NOT NULL, '
            'addedAt INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE history('
            'pageId INTEGER PRIMARY KEY, '
            'title TEXT NOT NULL, '
            'visitedAt INTEGER NOT NULL)',
          );
        },
      ),
    );
    _db = db;
    return db;
  }

  // ---- 收藏 ----

  Future<List<FavoriteEntry>> favorites() async {
    final db = await _database;
    final rows = await db.query('favorites', orderBy: 'addedAt DESC');
    return rows
        .map((row) => FavoriteEntry(
              pageId: row['pageId']! as int,
              title: row['title']! as String,
              addedAt:
                  DateTime.fromMillisecondsSinceEpoch(row['addedAt']! as int),
            ))
        .toList();
  }

  Future<void> addFavorite(int pageId, String title) async {
    final db = await _database;
    await db.insert(
      'favorites',
      <String, Object?>{
        'pageId': pageId,
        'title': title,
        'addedAt': await _nextTimestamp(db, 'favorites', 'addedAt'),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(int pageId) async {
    final db = await _database;
    await db.delete('favorites', where: 'pageId = ?', whereArgs: [pageId]);
  }

  Future<bool> isFavorite(int pageId) async {
    final db = await _database;
    final rows = await db.query(
      'favorites',
      columns: ['pageId'],
      where: 'pageId = ?',
      whereArgs: [pageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---- 历史 ----

  Future<List<HistoryEntry>> history({int limit = _historyLimit}) async {
    final db = await _database;
    final rows =
        await db.query('history', orderBy: 'visitedAt DESC', limit: limit);
    return rows
        .map((row) => HistoryEntry(
              pageId: row['pageId']! as int,
              title: row['title']! as String,
              visitedAt:
                  DateTime.fromMillisecondsSinceEpoch(row['visitedAt']! as int),
            ))
        .toList();
  }

  /// 记录一次访问：同一条目重访时更新 visitedAt（PK 覆盖即置顶），
  /// 并裁剪到最近 [_historyLimit] 条。
  Future<void> recordVisit(int pageId, String title) async {
    final db = await _database;
    await db.insert(
      'history',
      <String, Object?>{
        'pageId': pageId,
        'title': title,
        'visitedAt': await _nextTimestamp(db, 'history', 'visitedAt'),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _trimHistory(db);
  }

  /// 返回严格单调递增的时间戳（毫秒）：快速连续写入时
  /// DateTime.now() 可能并列，导致 DESC 排序次序不确定，
  /// 因此取 max(当前时间, 表内最大值 + 1)。
  Future<int> _nextTimestamp(
      Database db, String table, String column) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery('SELECT MAX($column) AS m FROM $table');
    final maxValue = rows.isEmpty ? null : rows.first['m'];
    final maxTs = maxValue is int ? maxValue : 0;
    return now > maxTs ? now : maxTs + 1;
  }

  Future<void> _trimHistory(Database db) async {
    // 删除超出上限的旧记录（按 visitedAt 排序保留最新 N 条）。
    await db.execute(
      'DELETE FROM history WHERE pageId NOT IN ('
      'SELECT pageId FROM history ORDER BY visitedAt DESC LIMIT ?)',
      [_historyLimit],
    );
  }

  Future<void> clearHistory() async {
    final db = await _database;
    await db.delete('history');
  }

  /// 关闭数据库连接；之后再次访问会重新打开。
  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
