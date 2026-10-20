/// App-wide constant values.
class AppConstants {
  AppConstants._();

  static const String appName = 'TeleDrive';

  // --- Secure storage keys (Bot Token is the only true secret) ---------------
  static const String keyBotToken = 'tg_bot_token';
  static const String keyChannelId = 'tg_channel_id';
  static const String keySyncFrequencyMinutes = 'sync_frequency_minutes';

  // --- Small preferences (not secrets, stored alongside them for simplicity) -
  static const String keyThemeMode = 'theme_mode';
  static const String keyKeepPhotoOriginal = 'keep_photo_original';
  static const String keySkippedUpdateVersion = 'skipped_update_version';

  // --- WorkManager task identifiers ------------------------------------------
  static const String periodicSyncTaskName = 'com.tgstorage.app.periodicSync';
  static const String periodicSyncUniqueName = 'teledrive-periodic-sync';

  /// Android WorkManager cannot run periodic tasks more often than 15
  /// minutes, so this is both our default and our minimum. One shared
  /// frequency applies to every Sync Link that has Auto-Sync turned on.
  static const int minSyncFrequencyMinutes = 15;
  static const int defaultSyncFrequencyMinutes = 15;

  // --- Telegram Bot API limits ------------------------------------------------
  // Source: https://core.telegram.org/bots/faq — bots can upload files up to
  // 50 MB via sendDocument/sendPhoto/sendVideo/sendAudio, and download files
  // up to 20 MB via getFile. These are platform limits, not something this
  // app can change.
  static const int maxUploadBytes = 50 * 1024 * 1024; // 50 MB
  static const int maxRedownloadBytes = 20 * 1024 * 1024; // 20 MB

  // --- Sync behaviour --------------------------------------------------------
  /// A background run stops starting new uploads after this long, so Android
  /// does not kill the worker mid-upload. The next cycle picks up the rest.
  static const Duration backgroundSyncBudget = Duration(minutes: 8);

  /// Files modified more recently than this are skipped for now. It stops the
  /// sync from uploading a half-copied or still-downloading file.
  static const Duration syncSettleTime = Duration(seconds: 45);

  /// Pause between uploads so a big folder stays under Telegram's rate limit.
  static const Duration syncUploadGap = Duration(milliseconds: 1200);

  // --- Misc ------------------------------------------------------------------
  static const String telegramApiBase = 'https://api.telegram.org';
  static const String botFatherUrl = 'https://t.me/BotFather';
}
