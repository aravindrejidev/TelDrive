/// App-wide constant values.
class AppConstants {
  AppConstants._();

  static const String appName = 'TeleDrive';

  // --- Secure storage keys (Bot Token is the only true secret) ---------------
  static const String keyBotToken = 'tg_bot_token';
  static const String keyChannelId = 'tg_channel_id';
  static const String keySyncFrequencyMinutes = 'sync_frequency_minutes';

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

  // --- Misc ------------------------------------------------------------------
  static const String telegramApiBase = 'https://api.telegram.org';
  static const String botFatherUrl = 'https://t.me/BotFather';
}
