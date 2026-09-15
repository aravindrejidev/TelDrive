import 'package:flutter/foundation.dart';
import '../models/sync_link.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/telegram_service.dart';
import '../utils/constants.dart';

enum SettingsLoadState { loading, needsSetup, ready }

/// Holds the primary Telegram credentials plus the full list of Sync Links.
///
/// This is the only place that talks to [SyncService]'s
/// schedule/cancel methods, so nothing else in the app has to remember to
/// keep WorkManager's registration in sync with what's shown on screen — any
/// change here (adding a link, toggling one, changing the shared frequency)
/// re-evaluates whether the background task should be running at all.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage = StorageService.instance;
  final DatabaseService _db = DatabaseService.instance;

  SettingsLoadState loadState = SettingsLoadState.loading;

  String? botToken;
  String? channelId;
  int syncFrequencyMinutes = AppConstants.defaultSyncFrequencyMinutes;
  List<SyncLink> syncLinks = [];

  bool get isConfigured =>
      botToken != null && botToken!.isNotEmpty && channelId != null && channelId!.isNotEmpty;

  bool get hasAnyAutoSyncEnabled => syncLinks.any((l) => l.autoSyncEnabled);

  Future<void> load() async {
    botToken = await _storage.getBotToken();
    channelId = await _storage.getChannelId();
    syncFrequencyMinutes = await _storage.getSyncFrequencyMinutes();
    syncLinks = await _db.getAllSyncLinks();
    loadState = isConfigured ? SettingsLoadState.ready : SettingsLoadState.needsSetup;
    notifyListeners();
  }

  /// Validates the credentials against the real Telegram API before saving
  /// them, so a typo is caught immediately on the setup screen.
  Future<void> saveCredentials({
    required String newBotToken,
    required String newChannelId,
  }) async {
    final trimmedToken = newBotToken.trim();
    final trimmedChannel = newChannelId.trim();

    await TelegramService(botToken: trimmedToken, channelId: trimmedChannel)
        .testConnection();

    await _storage.saveCredentials(botToken: trimmedToken, channelId: trimmedChannel);
    botToken = trimmedToken;
    channelId = trimmedChannel;
    loadState = SettingsLoadState.ready;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.clearCredentials();
    await SyncService.instance.cancelAutoSync();
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
    if (token == null) return;
    final trimmedChannel = targetChannelId.trim();
    await TelegramService(botToken: token, channelId: trimmedChannel).testConnection();

    final link = SyncLink(
      name: name.trim(),
      channelId: trimmedChannel,
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

  Future<void> _reconcileAutoSyncSchedule() async {
    if (hasAnyAutoSyncEnabled) {
      await SyncService.instance
          .ensureAutoSyncScheduled(frequencyMinutes: syncFrequencyMinutes);
    } else {
      await SyncService.instance.cancelAutoSync();
    }
  }
}
