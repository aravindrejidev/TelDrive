import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/telegram_service.dart';
import '../utils/helpers.dart';

enum FileSort { newest, oldest, name, size }

extension FileSortX on FileSort {
  String get label => switch (this) {
        FileSort.newest => 'Newest first',
        FileSort.oldest => 'Oldest first',
        FileSort.name => 'Name (A to Z)',
        FileSort.size => 'Largest first',
      };
}

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

  String _query = '';
  String get query => _query;

  FileSort _sort = FileSort.newest;
  FileSort get sort => _sort;

  void setQuery(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == _query) return;
    _query = normalized;
    notifyListeners();
  }

  void setSort(FileSort value) {
    if (value == _sort) return;
    _sort = value;
    notifyListeners();
  }

  /// The files of [category] after the current search and sort are applied.
  List<FileItem> filesFor(FileCategory category) {
    var list = _filesByCategory[category] ?? const <FileItem>[];
    if (_query.isNotEmpty) {
      list = list.where((f) => f.fileName.toLowerCase().contains(_query)).toList();
    }
    switch (_sort) {
      case FileSort.newest:
        return list;
      case FileSort.oldest:
        return list.reversed.toList();
      case FileSort.name:
        return List<FileItem>.of(list)
          ..sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
      case FileSort.size:
        return List<FileItem>.of(list)
          ..sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
    }
  }

  CategoryStat statsFor(FileCategory category) {
    final list = _filesByCategory[category] ?? const <FileItem>[];
    var bytes = 0;
    for (final item in list) {
      bytes += item.fileSizeBytes;
    }
    return CategoryStat(list.length, bytes);
  }

  int get totalCount =>
      FileCategory.values.fold(0, (sum, c) => sum + statsFor(c).count);

  int get totalBytes =>
      FileCategory.values.fold(0, (sum, c) => sum + statsFor(c).bytes);

  Future<void> loadAll() async {
    isLoading = true;
    notifyListeners();
    try {
      for (final category in FileCategory.values) {
        _filesByCategory[category] = await _db.getFilesByCategory(category);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addFileLocally(FileItem item) {
    final list = List<FileItem>.from(_filesByCategory[item.category] ?? []);
    list.insert(0, item);
    _filesByCategory[item.category] = list;
    notifyListeners();
  }

  /// Removes the file from the app. When [alsoDeleteFromTelegram] is true the
  /// channel message is deleted first - using this file's own channel (it may
  /// differ from the primary one if it came from a Sync Link) - and if that
  /// fails, nothing is removed and the error is thrown so the screen can offer
  /// a choice.
  ///
  /// The database row is kept as a hidden marker rather than deleted. That is
  /// what stops Sync from uploading the same file again from the phone.
  Future<void> deleteFile(FileItem item, {required bool alsoDeleteFromTelegram}) async {
    if (item.id == null) return;

    if (alsoDeleteFromTelegram) {
      final botToken = await StorageService.instance.getBotToken();
      final channelId = item.channelId ?? await StorageService.instance.getChannelId();
      if (botToken == null || channelId == null) {
        throw AppException('Telegram credentials are missing.');
      }
      try {
        await TelegramService(botToken: botToken, channelId: channelId)
            .deleteMessage(item.telegramMessageId);
      } on TelegramApiException catch (e) {
        if (!e.isMessageNotFound) rethrow;
      }
    }

    await _db.markRemoved(item.id!);
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
}
