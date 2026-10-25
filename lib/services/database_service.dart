import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/file_item.dart';
import '../models/sync_link.dart';

/// SQLite persistence for every tracked file and every Sync Link.
///
/// Schema history:
///  * v1 - single global folder and channel; `files` only.
///  * v2 - multi-channel: `files.channel_id` and the `sync_links` table.
///  * v3 - `files.is_removed` (a removed file stays as a hidden marker so Sync
///         never re-uploads it), `files.source_path` (the path a file was
///         uploaded from, never overwritten) and `sync_links.last_synced_at`.
///
/// [_open] migrates in place, so upgrading never loses file history.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String _dbName = 'teledrive.db';
  static const int _dbVersion = 3;
  static const String filesTable = 'files';
  static const String syncLinksTable = 'sync_links';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final db = await _open();
    _database = db;
    return db;
  }

  Future<Database> _open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createFilesTable(db);
        await _createSyncLinksTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Existing rows get channel_id = NULL, which the app reads as "the
          // primary channel" - exactly what those files already meant.
          await db.execute('ALTER TABLE $filesTable ADD COLUMN channel_id TEXT');
          await _createSyncLinksTableV2(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $filesTable ADD COLUMN is_removed INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE $filesTable ADD COLUMN source_path TEXT');
          await db.execute(
            'UPDATE $filesTable SET source_path = local_path WHERE local_path IS NOT NULL',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_files_source_path ON $filesTable (source_path)',
          );
          await db.execute(
            'ALTER TABLE $syncLinksTable ADD COLUMN last_synced_at TEXT',
          );
        }
      },
    );
  }

  Future<void> _createFilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $filesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL,
        telegram_file_id TEXT NOT NULL,
        telegram_unique_id TEXT,
        telegram_message_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT,
        local_path TEXT,
        source_path TEXT,
        uploaded_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'uploaded',
        channel_id TEXT,
        is_removed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_files_category ON $filesTable (category)');
    await db.execute('CREATE INDEX idx_files_local_path ON $filesTable (local_path)');
    await db.execute('CREATE INDEX idx_files_source_path ON $filesTable (source_path)');
  }

  Future<void> _createSyncLinksTable(Database db) async {
    await db.execute('''
      CREATE TABLE $syncLinksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        folder_path TEXT NOT NULL,
        auto_sync_enabled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_synced_at TEXT
      )
    ''');
  }

  /// The v2 shape, used only while upgrading from v1 (v3 adds the extra
  /// column afterwards).
  Future<void> _createSyncLinksTableV2(Database db) async {
    await db.execute('''
      CREATE TABLE $syncLinksTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        channel_id TEXT NOT NULL,
        folder_path TEXT NOT NULL,
        auto_sync_enabled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- files ------------------------------------------------------------

  Future<int> insertFile(FileItem item) async {
    final db = await database;
    return db.insert(filesTable, item.toMap()..remove('id'));
  }

  Future<void> updateFile(FileItem item) async {
    if (item.id == null) return;
    final db = await database;
    await db.update(filesTable, item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> updateLocalPath(int id, String? localPath) async {
    final db = await database;
    await db.update(
      filesTable,
      {'local_path': localPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hides a file from the app without forgetting that its source path was
  /// already handled. Using this instead of a hard delete is what stops Sync
  /// from re-uploading a file the user removed on purpose.
  Future<void> markRemoved(int id) async {
    final db = await database;
    await db.update(
      filesTable,
      {'is_removed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FileItem>> getFilesByCategory(FileCategory category) async {
    final db = await database;
    final rows = await db.query(
      filesTable,
      where: 'category = ? AND is_removed = 0',
      whereArgs: [category.dbValue],
      orderBy: 'uploaded_at DESC',
    );
    return rows.map(FileItem.fromMap).toList();
  }

  Future<List<FileItem>> getAllFiles() async {
    final db = await database;
    final rows = await db.query(
      filesTable,
      where: 'is_removed = 0',
      orderBy: 'uploaded_at DESC',
    );
    return rows.map(FileItem.fromMap).toList();
  }

  /// Every device path already uploaded to [channelId] (including files the
  /// user later removed). Rows from before multi-channel support have no
  /// channel and count for every channel, which errs on the side of not
  /// uploading a duplicate.
  Future<Set<String>> getTrackedPaths(String channelId) async {
    final db = await database;
    final rows = await db.query(
      filesTable,
      columns: ['source_path', 'local_path'],
      where: '(source_path IS NOT NULL OR local_path IS NOT NULL) '
          'AND (channel_id = ? OR channel_id IS NULL)',
      whereArgs: [channelId],
    );
    final paths = <String>{};
    for (final row in rows) {
      final source = row['source_path'] as String?;
      final local = row['local_path'] as String?;
      if (source != null) paths.add(source);
      if (local != null) paths.add(local);
    }
    return paths;
  }

  /// How many removed files are being remembered (see [markRemoved]).
  Future<int> removedCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $filesTable WHERE is_removed = 1',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Forgets removed files for good. Any of them that still sit in a sync
  /// folder will be uploaded again by the next sync.
  Future<int> purgeRemoved() async {
    final db = await database;
    return db.delete(filesTable, where: 'is_removed = 1');
  }

  /// Clears the "on this device" pointer of every file whose local copy lives
  /// under [directoryPath] (used when the downloaded copies are deleted).
  Future<void> clearLocalPathsUnder(String directoryPath) async {
    final db = await database;
    await db.update(
      filesTable,
      {'local_path': null},
      where: 'local_path IS NOT NULL AND substr(local_path, 1, ?) = ?',
      whereArgs: [directoryPath.length, directoryPath],
    );
  }

  // --- sync links ---------------------------------------------------------

  Future<int> insertSyncLink(SyncLink link) async {
    final db = await database;
    return db.insert(syncLinksTable, link.toMap()..remove('id'));
  }

  Future<void> updateSyncLink(SyncLink link) async {
    if (link.id == null) return;
    final db = await database;
    await db.update(syncLinksTable, link.toMap(), where: 'id = ?', whereArgs: [link.id]);
  }

  Future<void> updateSyncLinkLastSynced(int id, DateTime when) async {
    final db = await database;
    await db.update(
      syncLinksTable,
      {'last_synced_at': when.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSyncLink(int id) async {
    final db = await database;
    await db.delete(syncLinksTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SyncLink>> getAllSyncLinks() async {
    final db = await database;
    final rows = await db.query(syncLinksTable, orderBy: 'created_at ASC');
    return rows.map(SyncLink.fromMap).toList();
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
