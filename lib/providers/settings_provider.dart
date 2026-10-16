import 'package:flutter/material.dart';
import '../models/sync_link.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/telegram_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

enum SettingsLoadState { loading, needsSetup, ready }

/// Holds the primary Telegram credentials, preferences and the full list of
/// Sync Links.
///
/// This is the only place that talks to [SyncService]'s schedule/cancel
/// methods, so nothing else in the app has to remember to keep WorkManager's
/// registration in step with what is shown on screen - any change here
/// (adding a link, toggling one, changing the shared frequency, signing in
/// again) re-evaluates whether the background task should be running.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  final DatabaseService _db = DatabaseService.instance;

  SettingsLoadState loadState = SettingsLoadState.loading;

  String? botToken;
  String? channelId;
  int syncFrequencyMinutes = AppConstants.defaultSyncFrequencyMinutes;
  List<SyncLink> syncLinks = [];
  ThemeMode themeMode = ThemeMode.system;
  bool keepPhotoOriginal = true;

  bool get isConfigured =>
      botToken != null && botToken!.isNotEmpty && channelId != null && channelId!.isNotEmpty;

  bool get hasAnyAutoSyncEnabled => syncLinks.any((l) => l.autoSyncEnabled);

  Future<void> load() async {
    botToken = await _storage.getBotToken();
    channelId = await _storage.getChannelId();
    syncFrequencyMinutes = await _storage.getSyncFrequencyMinutes();
    syncLinks = await _db.getAllSyncLinks();
    themeMode = _themeModeFromName(await _storage.getThemeModeName());
    keepPhotoOriginal = await _storage.getKeepPhotoOriginal();
    loadState = isConfigured ? SettingsLoadState.ready : SettingsLoadState.needsSetup;
    notifyListeners();
  }

  ThemeMode _themeModeFromName(String name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _storage.setThemeModeName(mode.name);
  }

  Future<void> setKeepPhotoOriginal(bool keep) async {
    keepPhotoOriginal = keep;
    notifyListeners();
    await _storage.setKeepPhotoOriginal(keep);
  }

  /// Validates the credentials against the real Telegram API before saving
  /// them, so a typo is caught immediately on the setup screen.
  Future<void> saveCredentials({
    required String newBotToken,
    required String newChannelId,
  }) async {
    final trimmedToken = newBotToken.trim();
    final normalizedChannel = normalizeChannelId(newChannelId);

    await TelegramService(botToken: trimmedToken, channelId: normalizedChannel)
        .testConnection();

    await _storage.saveCredentials(botToken: trimmedToken, channelId: normalizedChannel);
    botToken = trimmedToken;
    channelId = normalizedChannel;

    // Sync Links survive a disconnect, so signing in again must bring the
    // background schedule back to match them.
    try {
      await _reconcileAutoSyncSchedule();
    } catch (_) {}

    loadState = SettingsLoadState.ready;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.clearCredentials();
    try {
      await SyncService.instance.cancelAutoSync();
    } catch (_) {}
    botToken = null;
    channelId = null;
    loadState = SettingsLoadState.needsSetup;
    notifyListeners();
  }

  /// Adds a new Sync Link, validating that the shared Bot Token can reach
  /// [targetChannelId] before saving it (same check used for the primary
  /// channel during setup).
  Future<void> addSyncLink({
    required String name,
    required String targetChannelId,
    required String folderPath,
  }) async {
    final token = botToken;
    if (token == null) throw AppException('Connect your bot first.');
    final normalizedChannel = normalizeChannelId(targetChannelId);

    final duplicate = syncLinks.any(
      (l) => l.folderPath == folderPath && l.channelId == normalizedChannel,
    );
    if (duplicate) {
      throw AppException('That folder is already linked to this channel.');
    }

    await TelegramService(botToken: token, channelId: normalizedChannel).testConnection();

    final link = SyncLink(
      name: name.trim(),
      channelId: normalizedChannel,
      folderPath: folderPath,
      createdAt: DateTime.now(),
    );
    final id = await _db.insertSyncLink(link);
    syncLinks = [...syncLinks, link.copyWith(id: id)];
    notifyListeners();
  }

  Future<void> removeSyncLink(SyncLink link) async {
    if (link.id == null) return;
    await _db.deleteSyncLink(link.id!);
    syncLinks = syncLinks.where((l) => l.id != link.id).toList();
    await _reconcileAutoSyncSchedule();
    notifyListeners();
  }

  Future<void> setSyncLinkAutoSync(SyncLink link, bool enabled) async {
    if (link.id == null) return;
    final updated = link.copyWith(autoSyncEnabled: enabled);
    await _db.updateSyncLink(updated);
    syncLinks = syncLinks.map((l) => l.id == link.id ? updated : l).toList();
    await _reconcileAutoSyncSchedule();
    notifyListeners();
  }

  Future<void> setSyncFrequencyMinutes(int minutes) async {
    syncFrequencyMinutes = minutes;
    await _storage.setSyncFrequencyMinutes(minutes);
    await _reconcileAutoSyncSchedule();
    notifyListeners();
  }

  /// Re-reads the links, for example to show the new "last synced" time after
  /// a manual sync.
  Future<void> refreshSyncLinks() async {
    syncLinks = await _db.getAllSyncLinks();
    notifyListeners();
  }

  Future<void> _reconcileAutoSyncSchedule() async {
    if (hasAnyAutoSyncEnabled) {
      await SyncService.instance
          .ensureAutoSyncScheduled(frequencyMinutes: syncFrequencyMinutes);
    } else {
      await SyncService.instance.cancelAutoSync();
    }
  }
}
