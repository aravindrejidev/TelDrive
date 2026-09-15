import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/telegram_service.dart';

/// Loads the SQLite-tracked file list for each tab and applies edits.
class FileProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  final Map<FileCategory, List<FileItem>> _filesByCategory = {
    FileCategory.photo: [],
    FileCategory.video: [],
    FileCategory.audio: [],
    FileCategory.document: [],
  };

  bool isLoading = false;

  List<FileItem> filesFor(FileCategory category) =>
      List.unmodifiable(_filesByCategory[category] ?? const []);

  Future<void> loadAll() async {
    isLoading = true;
    notifyListeners();
    for (final category in FileCategory.values) {
      _filesByCategory[category] = await _db.getFilesByCategory(category);
    }
    isLoading = false;
    notifyListeners();
  }

  void addFileLocally(FileItem item) {
    final list = List<FileItem>.from(_filesByCategory[item.category] ?? []);
    list.insert(0, item);
    _filesByCategory[item.category] = list;
    notifyListeners();
  }

  /// Removes the row from SQLite. When [alsoDeleteFromTelegram] is true, the
  /// channel message is deleted too — using this specific file's own
  /// channel (it may differ from the primary channel if it came from a
  /// Sync Link), falling back to the primary channel for rows created
  /// before multi-channel support existed.
  Future<void> deleteFile(FileItem item, {required bool alsoDeleteFromTelegram}) async {
    if (item.id == null) return;

    if (alsoDeleteFromTelegram) {
      final botToken = await StorageService.instance.getBotToken();
      final channelId = item.channelId ?? await StorageService.instance.getChannelId();
      if (botToken != null && channelId != null) {
        await TelegramService(botToken: botToken, channelId: channelId)
            .deleteMessage(item.telegramMessageId);
      }
    }

    await _db.deleteFile(item.id!);
    final list = List<FileItem>.from(_filesByCategory[item.category] ?? []);
    list.removeWhere((f) => f.id == item.id);
    _filesByCategory[item.category] = list;
    notifyListeners();
  }

  Future<void> clearLocalPath(FileItem item) async {
    if (item.id == null) return;
    await _db.updateLocalPath(item.id!, null);
    _replace(item.copyWith(clearLocalPath: true));
  }

  Future<void> setLocalPath(FileItem item, String path) async {
    if (item.id == null) return;
    await _db.updateLocalPath(item.id!, path);
    _replace(item.copyWith(localPath: path));
  }

  void _replace(FileItem updated) {
    final list = List<FileItem>.from(_filesByCategory[updated.category] ?? []);
    final index = list.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      list[index] = updated;
      _filesByCategory[updated.category] = list;
      notifyListeners();
    }
  }

  Future<Map<FileCategory, int>> getCounts() => _db.getCountsByCategory();
}
