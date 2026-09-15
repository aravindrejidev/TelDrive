import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/telegram_service.dart';
import '../utils/constants.dart';
import '../utils/file_type_helper.dart';
import 'file_provider.dart';

enum UploadTaskStatus { uploading, success, failed }

class UploadTask {
  UploadTask({
    required this.id,
    required this.fileName,
    required this.category,
    required this.totalBytes,
  });

  final String id;
  final String fileName;
  final FileCategory category;
  final int totalBytes;

  double progress = 0;
  UploadTaskStatus status = UploadTaskStatus.uploading;
  String? errorMessage;

  bool get exceedsRedownloadLimit => totalBytes > AppConstants.maxRedownloadBytes;
}

/// Drives the manual "pick a file and upload it" flow. Manual uploads from
/// the Photos/Videos/Audio/Documents tabs always go to the primary channel
/// (Sync Links are for automatic folder syncing only — see SettingsScreen).
class UploadProvider extends ChangeNotifier {
  final Map<String, UploadTask> _tasks = {};
  int _taskCounter = 0;

  List<UploadTask> get tasks => _tasks.values.toList().reversed.toList();

  Future<void> pickAndUpload({
    required FileCategory category,
    required FileProvider fileProvider,
  }) async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: switch (category) {
        FileCategory.photo => FileType.image,
        FileCategory.video => FileType.video,
        FileCategory.audio => FileType.audio,
        FileCategory.document => FileType.any,
      },
      allowMultiple: true,
    );

    if (picked.isEmpty) return;

    final botToken = await StorageService.instance.getBotToken();
    final channelId = await StorageService.instance.getChannelId();
    if (botToken == null || channelId == null) return;

    final telegram = TelegramService(botToken: botToken, channelId: channelId);

    for (final platformFile in picked) {
      final path = platformFile.path;
      if (path == null) continue;
      unawaited(_uploadOne(
        file: File(path),
        fileName: platformFile.name,
        category: category,
        channelId: channelId,
        telegram: telegram,
        fileProvider: fileProvider,
      ));
    }
  }

  Future<void> uploadSingleFile({
    required File file,
    required String fileName,
    required FileCategory category,
    required FileProvider fileProvider,
  }) async {
    final botToken = await StorageService.instance.getBotToken();
    final channelId = await StorageService.instance.getChannelId();
    if (botToken == null || channelId == null) return;
    final telegram = TelegramService(botToken: botToken, channelId: channelId);
    await _uploadOne(
      file: file,
      fileName: fileName,
      category: category,
      channelId: channelId,
      telegram: telegram,
      fileProvider: fileProvider,
    );
  }

  Future<void> _uploadOne({
    required File file,
    required String fileName,
    required FileCategory category,
    required String channelId,
    required TelegramService telegram,
    required FileProvider fileProvider,
  }) async {
    final id = 'upload_${_taskCounter++}';
    final length = await file.length();
    final task = UploadTask(
      id: id,
      fileName: fileName,
      category: category,
      totalBytes: length,
    );
    _tasks[id] = task;
    notifyListeners();

    if (length > AppConstants.maxUploadBytes) {
      task.status = UploadTaskStatus.failed;
      task.errorMessage =
          'File is larger than the 50 MB Telegram Bot API upload limit.';
      notifyListeners();
      return;
    }

    try {
      final result = await telegram.uploadFile(
        file: file,
        fileName: fileName,
        category: category,
        onProgress: (sent, total) {
          task.progress = total > 0 ? sent / total : 0;
          notifyListeners();
        },
      );

      final item = FileItem(
        fileName: fileName,
        telegramFileId: result.fileId,
        telegramUniqueId: result.fileUniqueId,
        telegramMessageId: result.messageId,
        category: category,
        fileSizeBytes: result.fileSize,
        mimeType: FileTypeHelper.mimeTypeForFileName(fileName),
        localPath: file.path,
        uploadedAt: DateTime.now(),
        channelId: channelId,
      );
      final insertedId = await DatabaseService.instance.insertFile(item);
      fileProvider.addFileLocally(item.copyWith(id: insertedId));

      task.status = UploadTaskStatus.success;
      task.progress = 1;
    } catch (e) {
      task.status = UploadTaskStatus.failed;
      task.errorMessage = e.toString();
    }
    notifyListeners();
  }

  void dismissTask(String id) {
    _tasks.remove(id);
    notifyListeners();
  }

  void clearFinished() {
    _tasks.removeWhere((_, task) => task.status != UploadTaskStatus.uploading);
    notifyListeners();
  }
}
