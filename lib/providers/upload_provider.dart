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
import '../utils/helpers.dart';
import 'file_provider.dart';

enum UploadTaskStatus { queued, uploading, success, failed }

class UploadTask {
  UploadTask({
    required this.id,
    required this.file,
    required this.fileName,
    required this.category,
    required this.totalBytes,
  });

  final String id;
  final File file;
  final String fileName;
  final FileCategory category;
  int totalBytes;

  double progress = 0;
  UploadTaskStatus status = UploadTaskStatus.queued;
  String? errorMessage;

  bool get isFinished =>
      status == UploadTaskStatus.success || status == UploadTaskStatus.failed;

  bool get exceedsRedownloadLimit => totalBytes > AppConstants.maxRedownloadBytes;
}

/// Drives the manual "pick a file and upload it" flow. Manual uploads from
/// the Photos/Videos/Audio/Documents tabs always go to the primary channel
/// (Sync Links are for automatic folder syncing only - see SettingsScreen).
///
/// Uploads run two at a time; the rest wait in a visible queue.
class UploadProvider extends ChangeNotifier {
  int _maxConcurrent = 2;
  int get maxConcurrent => _maxConcurrent;

  /// How many uploads run at once (1 to 4). Raising it starts waiting ones.
  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 4);
    _pump();
  }

  final Map<String, UploadTask> _tasks = {};
  final List<Future<void> Function()> _pending = [];
  int _active = 0;
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

    for (final platformFile in picked) {
      final path = platformFile.path;
      if (path == null) continue;

      // Trust the real file type over the tab it was picked from, so a FLAC
      // chosen in the Documents tab still lands under Audio. Unknown types
      // stay in the tab the person was looking at.
      final detected = FileTypeHelper.categoryForFileName(platformFile.name);
      final effective = detected == FileCategory.document ? category : detected;

      final file = File(path);
      var size = 0;
      try {
        size = await file.length();
      } catch (_) {
        // The real size is read again when the upload starts.
      }

      _enqueue(
        file: file,
        fileName: platformFile.name,
        category: effective,
        size: size,
        fileProvider: fileProvider,
      );
    }
  }

  void _enqueue({
    required File file,
    required String fileName,
    required FileCategory category,
    required int size,
    required FileProvider fileProvider,
  }) {
    final id = 'upload_${_taskCounter++}';
    final task = UploadTask(
      id: id,
      file: file,
      fileName: fileName,
      category: category,
      totalBytes: size,
    );
    _tasks[id] = task;
    notifyListeners();
    _pending.add(() => _run(task, fileProvider));
    _pump();
  }

  void _pump() {
    while (_active < _maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _active++;
      job().whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  Future<void> _run(UploadTask task, FileProvider fileProvider) async {
    task.status = UploadTaskStatus.uploading;
    task.progress = 0;
    task.errorMessage = null;
    notifyListeners();

    try {
      final length = await task.file.length();
      task.totalBytes = length;
      if (length > AppConstants.maxUploadBytes) {
        throw AppException(
          'This file is over the 50 MB limit Telegram sets for bot uploads.',
        );
      }

      final botToken = await StorageService.instance.getBotToken();
      final channelId = await StorageService.instance.getChannelId();
      if (botToken == null || channelId == null) {
        throw AppException('Telegram credentials are missing.');
      }
      final keepOriginal = await StorageService.instance.getKeepPhotoOriginal();
      final silent = await StorageService.instance
          .getBool(AppConstants.keySilentUploads, fallback: true);
      final telegram = TelegramService(botToken: botToken, channelId: channelId);

      final result = await telegram.uploadFile(
        file: task.file,
        fileName: task.fileName,
        category: task.category,
        keepPhotoOriginal: keepOriginal,
        silent: silent,
        onProgress: (sent, total) {
          final value = total > 0 ? sent / total : 0.0;
          // Repaint at most every 1%; chunks arrive far more often than that.
          if (value - task.progress >= 0.01 || value >= 1) {
            task.progress = value;
            notifyListeners();
          }
        },
      );

      final item = FileItem(
        fileName: task.fileName,
        telegramFileId: result.fileId,
        telegramUniqueId: result.fileUniqueId,
        telegramMessageId: result.messageId,
        category: task.category,
        fileSizeBytes: result.fileSize,
        mimeType: FileTypeHelper.mimeTypeForFileName(task.fileName),
        localPath: task.file.path,
        sourcePath: task.file.path,
        uploadedAt: DateTime.now(),
        channelId: channelId,
      );
      final insertedId = await DatabaseService.instance.insertFile(item);
      fileProvider.addFileLocally(item.copyWith(id: insertedId));

      task.status = UploadTaskStatus.success;
      task.progress = 1;
      notifyListeners();

      // Finished uploads tidy themselves away; failures stay until dismissed.
      unawaited(Future<void>.delayed(const Duration(seconds: 4), () {
        if (_tasks[task.id]?.status == UploadTaskStatus.success) {
          dismissTask(task.id);
        }
      }));
    } catch (e) {
      task.status = UploadTaskStatus.failed;
      task.errorMessage = friendlyError(e);
      notifyListeners();
    }
  }

  /// Puts a failed upload back in the queue.
  void retry(String id, FileProvider fileProvider) {
    final task = _tasks[id];
    if (task == null || task.status != UploadTaskStatus.failed) return;
    task.status = UploadTaskStatus.queued;
    task.errorMessage = null;
    notifyListeners();
    _pending.add(() => _run(task, fileProvider));
    _pump();
  }

  void dismissTask(String id) {
    if (_tasks.remove(id) != null) notifyListeners();
  }

  void clearFinished() {
    _tasks.removeWhere((_, task) => task.isFinished);
    notifyListeners();
  }
}
