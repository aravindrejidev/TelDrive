import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';
import '../models/file_item.dart';
import '../models/sync_link.dart';
import '../utils/constants.dart';
import '../utils/file_type_helper.dart';
import '../utils/helpers.dart';
import 'database_service.dart';
import 'storage_service.dart';
import 'telegram_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == AppConstants.periodicSyncTaskName) {
      try {
        await SyncService.instance.runAutoSyncEnabledLinks();
        return true;
      } catch (_) {
        return false;
      }
    }
    return true;
  });
}

class SyncResult {
  const SyncResult({
    this.uploaded = 0,
    this.failed = 0,
    this.skipped = 0,
    this.tooLarge = 0,
    this.busy = false,
    this.timedOut = false,
    this.lastError,
  });

  final int uploaded;
  final int failed;

  /// Files left for a later run: still being written, unreadable, or empty.
  final int skipped;

  /// Files over Telegram's 50 MB bot upload limit. They can never be synced.
  final int tooLarge;

  /// Another sync was already running, so this call did nothing.
  final bool busy;

  /// The time budget ran out; the remaining files wait for the next run.
  final bool timedOut;

  /// The most recent failure, in plain language.
  final String? lastError;

  int get totalConsidered => uploaded + failed + skipped + tooLarge;

  SyncResult operator +(SyncResult other) => SyncResult(
        uploaded: uploaded + other.uploaded,
        failed: failed + other.failed,
        skipped: skipped + other.skipped,
        tooLarge: tooLarge + other.tooLarge,
        busy: busy || other.busy,
        timedOut: timedOut || other.timedOut,
        lastError: other.lastError ?? lastError,
      );
}

class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  bool _isRunning = false;

  static const Set<String> _temporaryExtensions = {
    'tmp', 'temp', 'part', 'partial', 'crdownload', 'download', 'cache',
  };

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> ensureAutoSyncScheduled({
    required int frequencyMinutes,
    bool wifiOnly = false,
    bool requiresCharging = false,
    bool batteryNotLow = false,
  }) async {
    final minutes = frequencyMinutes < AppConstants.minSyncFrequencyMinutes
        ? AppConstants.minSyncFrequencyMinutes
        : frequencyMinutes;
    await Workmanager().cancelByUniqueName(AppConstants.periodicSyncUniqueName);
    await Workmanager().registerPeriodicTask(
      AppConstants.periodicSyncUniqueName,
      AppConstants.periodicSyncTaskName,
      frequency: Duration(minutes: minutes),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresCharging: requiresCharging,
        requiresBatteryNotLow: batteryNotLow,
      ),
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
    return _runLinks(
      links.where((l) => l.autoSyncEnabled).toList(),
      budget: AppConstants.backgroundSyncBudget,
    );
  }

  Future<SyncResult> runAllLinksNow() async {
    final links = await DatabaseService.instance.getAllSyncLinks();
    return _runLinks(links);
  }

  Future<SyncResult> runLinkNow(SyncLink link) => _runLinks([link]);

  Future<SyncResult> _runLinks(List<SyncLink> links, {Duration? budget}) async {
    if (_isRunning) return const SyncResult(busy: true);

    final botToken = await StorageService.instance.getBotToken();
    if (botToken == null || botToken.isEmpty) return const SyncResult();
    final keepPhotoOriginal = await StorageService.instance.getKeepPhotoOriginal();
    final silent = await StorageService.instance
        .getBool(AppConstants.keySilentUploads, fallback: true);
    final deadline = budget == null ? null : DateTime.now().add(budget);

    _isRunning = true;
    try {
      var total = const SyncResult();
      for (final link in links) {
        if (deadline != null && DateTime.now().isAfter(deadline)) {
          total = total + const SyncResult(timedOut: true);
          break;
        }
        total = total +
            await _syncLink(
              link,
              botToken: botToken,
              keepPhotoOriginal: keepPhotoOriginal,
              silent: silent,
              deadline: deadline,
            );
      }
      return total;
    } finally {
      _isRunning = false;
    }
  }

  bool _isTemporary(String fileName) {
    if (fileName.endsWith('~')) return true;
    return _temporaryExtensions.contains(FileTypeHelper.extensionOf(fileName));
  }

  Future<SyncResult> _syncLink(
    SyncLink link, {
    required String botToken,
    required bool keepPhotoOriginal,
    required bool silent,
    DateTime? deadline,
  }) async {
    final folder = Directory(link.folderPath);
    if (!await folder.exists()) {
      return SyncResult(lastError: 'The folder for "${link.name}" is missing or unreadable.');
    }

    final telegram = TelegramService(botToken: botToken, channelId: link.channelId);
    final db = DatabaseService.instance;
    final tracked = await db.getTrackedPaths(link.channelId);

    var uploaded = 0;
    var failed = 0;
    var skipped = 0;
    var tooLarge = 0;
    var consecutiveFailures = 0;
    var timedOut = false;
    String? lastError;

    // Collect first: a folder we cannot fully read (for example a subfolder
    // without permission) should not abort the whole scan.
    final candidates = <File>[];
    await for (final entity in folder
        .list(recursive: true, followLinks: false)
        .handleError((Object _) {}, test: (e) => e is FileSystemException)) {
      if (entity is File) candidates.add(entity);
    }

    for (final entity in candidates) {
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        timedOut = true;
        break;
      }

      final path = entity.path;
      final fileName = p.basename(path);
      if (fileName.startsWith('.') || _isTemporary(fileName)) continue;
      if (tracked.contains(path)) continue;

      FileStat stat;
      try {
        stat = await entity.stat();
      } catch (_) {
        skipped++;
        continue;
      }
      if (stat.type != FileSystemEntityType.file) continue;
      if (stat.size <= 0) {
        skipped++;
        continue;
      }
      if (stat.size > AppConstants.maxUploadBytes) {
        tooLarge++;
        continue;
      }
      if (DateTime.now().difference(stat.modified) < AppConstants.syncSettleTime) {
        skipped++; // Probably still being written; the next run will get it.
        continue;
      }

      final category = FileTypeHelper.categoryForFileName(fileName);
      try {
        final result = await telegram.uploadFile(
          file: entity,
          fileName: fileName,
          category: category,
          keepPhotoOriginal: keepPhotoOriginal,
          silent: silent,
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
            sourcePath: path,
            uploadedAt: DateTime.now(),
            channelId: link.channelId,
          ),
        );
        tracked.add(path);
        uploaded++;
        consecutiveFailures = 0;
      } catch (e) {
        failed++;
        consecutiveFailures++;
        lastError = friendlyError(e);

        // A rejected token or a channel the bot was removed from will fail
        // every remaining file the same way - stop instead of hammering.
        final fatal = e is TelegramApiException &&
            (e.errorCode == 401 || e.errorCode == 403);
        if (fatal || consecutiveFailures >= 3) break;
      }

      await Future<void>.delayed(AppConstants.syncUploadGap);
    }

    if (link.id != null) {
      await db.updateSyncLinkLastSynced(link.id!, DateTime.now());
    }

    return SyncResult(
      uploaded: uploaded,
      failed: failed,
      skipped: skipped,
      tooLarge: tooLarge,
      timedOut: timedOut,
      lastError: lastError,
    );
  }
}
