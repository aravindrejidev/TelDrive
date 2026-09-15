import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/file_item.dart';
import '../models/sync_link.dart';

/// SQLite persistence for every tracked file and every Sync Link.
///
/// Existing installs are on schema v1 (no `channel_id` column, no
/// `sync_links` table at all — the app had exactly one global folder and
/// one global channel). [_open] runs a real migration via `onUpgrade` so
/// upgrading the app in place doesn't lose anyone's existing file history.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const String _dbName = 'teledrive.db';
  static const int _dbVersion = 2;
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
          // v1 -> v2: multi-channel support. Existing rows get channel_id =
          // NULL, which the rest of the app treats as "the primary channel"
          // — exactly what those files already meant before this update.
          await db.execute('ALTER TABLE $filesTable ADD COLUMN channel_id TEXT');
          await _createSyncLinksTable(db);
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
        uploaded_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'uploaded',
        channel_id TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_files_category ON $filesTable (category)');
    await db.execute('CREATE INDEX idx_files_local_path ON $filesTable (local_path)');
  }

  Future<void> _createSyncLinksTable(Database db) async {
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

  Future<void> deleteFile(int id) async {
    final db = await database;
    await db.delete(filesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FileItem>> getFilesByCategory(FileCategory category) async {
    final db = await database;
    final rows = await db.query(
      filesTable,
      where: 'category = ?',
      whereArgs: [category.dbValue],
      orderBy: 'uploaded_at DESC',
    );
    return rows.map(FileItem.fromMap).toList();
  }

  Future<List<FileItem>> getAllFiles() async {
    final db = await database;
    final rows = await db.query(filesTable, orderBy: 'uploaded_at DESC');
    return rows.map(FileItem.fromMap).toList();
  }

  /// Used by the sync worker to avoid re-uploading a file it already
  /// uploaded from this exact path on a previous run (regardless of which
  /// Sync Link that upload came from).
  Future<bool> existsByLocalPath(String localPath) async {
    final db = await database;
    final rows = await db.query(
      filesTable,
      columns: ['id'],
      where: 'local_path = ?',
      whereArgs: [localPath],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<FileCategory, int>> getCountsByCategory() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) as c FROM $filesTable GROUP BY category',
    );
    final result = <FileCategory, int>{
      FileCategory.photo: 0,
      FileCategory.video: 0,
      FileCategory.audio: 0,
      FileCategory.document: 0,
    };
    for (final row in rows) {
      final category = FileCategoryX.fromDbValue(row['category'] as String);
      result[category] = row['c'] as int;
    }
    return result;
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
