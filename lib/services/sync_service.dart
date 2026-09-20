import 'dart:io';
import 'package:workmanager/workmanager.dart';
import '../models/file_item.dart';
import '../models/sync_link.dart';
import '../utils/constants.dart';
import '../utils/file_type_helper.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'telegram_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == AppConstants.periodicSyncTaskName) {
      try {
        await SyncService.instance.runAutoSyncEnabledLinks();
        return Future.value(true);
      } catch (_) {
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

class SyncResult {
  const SyncResult({required this.uploaded, required this.failed, required this.skipped});
  final int uploaded;
  final int failed;
  final int skipped;

  int get totalConsidered => uploaded + failed + skipped;

  SyncResult operator +(SyncResult other) => SyncResult(
        uploaded: uploaded + other.uploaded,
        failed: failed + other.failed,
        skipped: skipped + other.skipped,
      );
}

class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> ensureAutoSyncScheduled({required int frequencyMinutes}) async {
    final minutes = frequencyMinutes < AppConstants.minSyncFrequencyMinutes
        ? AppConstants.minSyncFrequencyMinutes
        : frequencyMinutes;
    await Workmanager().cancelByUniqueName(AppConstants.periodicSyncUniqueName);
    await Workmanager().registerPeriodicTask(
      AppConstants.periodicSyncUniqueName,
      AppConstants.periodicSyncTaskName,
      frequency: Duration(minutes: minutes),
      constraints: Constraints(networkType: NetworkType.connected),
      foregroundServiceConfig: ForegroundServiceConfig(
        notificationTitle: 'TeleDrive Auto-Sync',
        notificationText: 'Checking your sync folders for new files…',
      ),
    );
  }

  Future<void> cancelAutoSync() async {
    await Workmanager().cancelByUniqueName(AppConstants.periodicSyncUniqueName);
  }

  Future<SyncResult> runAutoSyncEnabledLinks() async {
    final links = await DatabaseService.instance.getAllSyncLinks();
    return _runLinks(links.where((l) => l.autoSyncEnabled).toList());
  }

  Future<SyncResult> runAllLinksNow() async {
    final links = await DatabaseService.instance.getAllSyncLinks();
    return _runLinks(links);
  }

  Future<SyncResult> _runLinks(List<SyncLink> links) async {
    final botToken = await StorageService.instance.getBotToken();
    if (botToken == null) {
      return const SyncResult(uploaded: 0, failed: 0, skipped: 0);
    }
    var total = const SyncResult(uploaded: 0, failed: 0, skipped: 0);
    for (final link in links) {
      total = total + await runSyncLink(link, botToken: botToken);
    }
    return total;
  }

  Future<SyncResult> runSyncLink(SyncLink link, {required String botToken}) async {
    final folder = Directory(link.folderPath);
    if (!await folder.exists()) {
      return const SyncResult(uploaded: 0, failed: 0, skipped: 0);
    }

    final telegram = TelegramService(botToken: botToken, channelId: link.channelId);
    final db = DatabaseService.instance;

    var uploaded = 0;
    var failed = 0;
    var skipped = 0;

    await for (final entity in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      final fileName = path.split(Platform.pathSeparator).last;

      if (fileName.startsWith('.')) continue;
      if (await db.existsByLocalPath(path)) continue;

      int length;
      try {
        length = await entity.length();
      } catch (_) {
        skipped++;
        continue;
      }
      if (length <= 0 || length > AppConstants.maxUploadBytes) {
        skipped++;
        continue;
      }

      final category = FileTypeHelper.categoryForFileName(fileName);

      try {
        final result = await telegram.uploadFile(
          file: entity,
          fileName: fileName,
          category: category,
        );
        await db.insertFile(
          FileItem(
            fileName: fileName,
            telegramFileId: result.fileId,
            telegramUniqueId: result.fileUniqueId,
            telegramMessageId: result.messageId,
            category: category,
            fileSizeBytes: result.fileSize,
            mimeType: FileTypeHelper.mimeTypeForFileName(fileName),
            localPath: path,
            uploadedAt: DateTime.now(),
            channelId: link.channelId,
          ),
        );
        uploaded++;
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(uploaded: uploaded, failed: failed, skipped: skipped);
  }
}
