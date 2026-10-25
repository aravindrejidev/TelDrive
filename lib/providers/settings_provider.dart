import 'package:flutter/material.dart';
import '../models/sync_link.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/telegram_service.dart';
import '../theme/neu_theme.dart';
import '../utils/constants.dart';
import '../utils/haptics.dart';
import '../utils/helpers.dart';
import 'file_provider.dart';

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
  // --- Appearance
  ThemeMode themeMode = ThemeMode.system;
  AccentPalette accentPalette = AccentPalette.indigo;
  bool hapticsEnabled = true;

  // --- Library
  FileSort defaultSort = FileSort.newest;
  int startTabIndex = 0;
  bool showThumbnails = true;
  bool confirmPermanentDelete = true;

  // --- Uploads
  bool keepPhotoOriginal = true;
  bool silentUploads = true;
  int maxConcurrentUploads = 2;

  // --- Sync conditions (applied through WorkManager)
  bool syncWifiOnly = false;
  bool syncOnlyCharging = false;
  bool syncBatteryNotLow = false;

  // --- Updates
  bool autoCheckUpdates = true;

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

    accentPalette = _enumByName(
      AccentPalette.values,
      await _storage.getString(AppConstants.keyAccentPalette),
      AccentPalette.indigo,
    );
    hapticsEnabled = await _storage.getBool(AppConstants.keyHaptics, fallback: true);
    Haptics.enabled = hapticsEnabled;

    defaultSort = _enumByName(
      FileSort.values,
      await _storage.getString(AppConstants.keyDefaultSort),
      FileSort.newest,
    );
    startTabIndex =
        (await _storage.getInt(AppConstants.keyStartTab, fallback: 0)).clamp(0, 3);
    showThumbnails =
        await _storage.getBool(AppConstants.keyShowThumbnails, fallback: true);
    confirmPermanentDelete =
        await _storage.getBool(AppConstants.keyConfirmPermanentDelete, fallback: true);

    silentUploads = await _storage.getBool(AppConstants.keySilentUploads, fallback: true);
    maxConcurrentUploads =
        (await _storage.getInt(AppConstants.keyMaxConcurrentUploads, fallback: 2))
            .clamp(1, 4);

    syncWifiOnly = await _storage.getBool(AppConstants.keySyncWifiOnly, fallback: false);
    syncOnlyCharging =
        await _storage.getBool(AppConstants.keySyncOnlyCharging, fallback: false);
    syncBatteryNotLow =
        await _storage.getBool(AppConstants.keySyncBatteryNotLow, fallback: false);

    autoCheckUpdates =
        await _storage.getBool(AppConstants.keyAutoCheckUpdates, fallback: true);
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

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  // --- Appearance ---------------------------------------------------------

  Future<void> setAccentPalette(AccentPalette palette) async {
    accentPalette = palette;
    notifyListeners();
    await _storage.setString(AppConstants.keyAccentPalette, palette.name);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    hapticsEnabled = enabled;
    Haptics.enabled = enabled;
    notifyListeners();
    await _storage.setBool(AppConstants.keyHaptics, enabled);
  }

  // --- Library ------------------------------------------------------------

  Future<void> setDefaultSort(FileSort sort) async {
    defaultSort = sort;
    notifyListeners();
    await _storage.setString(AppConstants.keyDefaultSort, sort.name);
  }

  Future<void> setStartTabIndex(int index) async {
    startTabIndex = index.clamp(0, 3);
    notifyListeners();
    await _storage.setInt(AppConstants.keyStartTab, startTabIndex);
  }

  Future<void> setShowThumbnails(bool show) async {
    showThumbnails = show;
    notifyListeners();
    await _storage.setBool(AppConstants.keyShowThumbnails, show);
  }

  Future<void> setConfirmPermanentDelete(bool confirm) async {
    confirmPermanentDelete = confirm;
    notifyListeners();
    await _storage.setBool(AppConstants.keyConfirmPermanentDelete, confirm);
  }

  // --- Uploads ------------------------------------------------------------

  Future<void> setSilentUploads(bool silent) async {
    silentUploads = silent;
    notifyListeners();
    await _storage.setBool(AppConstants.keySilentUploads, silent);
  }

  Future<void> setMaxConcurrentUploads(int count) async {
    maxConcurrentUploads = count.clamp(1, 4);
    notifyListeners();
    await _storage.setInt(AppConstants.keyMaxConcurrentUploads, maxConcurrentUploads);
  }

  // --- Sync conditions ----------------------------------------------------

  Future<void> setSyncWifiOnly(bool value) async {
    syncWifiOnly = value;
    notifyListeners();
    await _storage.setBool(AppConstants.keySyncWifiOnly, value);
    await _reconcileAutoSyncSchedule();
  }

  Future<void> setSyncOnlyCharging(bool value) async {
    syncOnlyCharging = value;
    notifyListeners();
    await _storage.setBool(AppConstants.keySyncOnlyCharging, value);
    await _reconcileAutoSyncSchedule();
  }

  Future<void> setSyncBatteryNotLow(bool value) async {
    syncBatteryNotLow = value;
    notifyListeners();
    await _storage.setBool(AppConstants.keySyncBatteryNotLow, value);
    await _reconcileAutoSyncSchedule();
  }

  // --- Updates ------------------------------------------------------------

  Future<void> setAutoCheckUpdates(bool value) async {
    autoCheckUpdates = value;
    notifyListeners();
    await _storage.setBool(AppConstants.keyAutoCheckUpdates, value);
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
      await SyncService.instance.ensureAutoSyncScheduled(
        frequencyMinutes: syncFrequencyMinutes,
        wifiOnly: syncWifiOnly,
        requiresCharging: syncOnlyCharging,
        batteryNotLow: syncBatteryNotLow,
      );
    } else {
      await SyncService.instance.cancelAutoSync();
    }
  }
}
