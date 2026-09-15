import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

/// Thin wrapper around [FlutterSecureStorage] for the two real secrets (Bot
/// Token, primary Channel ID) plus the one small shared preference
/// (Auto-Sync frequency, which applies to every Sync Link).
///
/// Sync Links themselves (name + folder + channel + per-link toggle) live in
/// SQLite via [DatabaseService] instead — there can be many of them, and
/// SQLite is a much better fit for a growing list of records than secure
/// storage's flat key-value model.
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveCredentials({
    required String botToken,
    required String channelId,
  }) async {
    await _storage.write(key: AppConstants.keyBotToken, value: botToken.trim());
    await _storage.write(key: AppConstants.keyChannelId, value: channelId.trim());
  }

  Future<String?> getBotToken() => _storage.read(key: AppConstants.keyBotToken);

  Future<String?> getChannelId() => _storage.read(key: AppConstants.keyChannelId);

  Future<bool> hasCredentials() async {
    final token = await getBotToken();
    final channel = await getChannelId();
    return token != null && token.isNotEmpty && channel != null && channel.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: AppConstants.keyBotToken);
    await _storage.delete(key: AppConstants.keyChannelId);
  }

  Future<void> setSyncFrequencyMinutes(int minutes) => _storage.write(
        key: AppConstants.keySyncFrequencyMinutes,
        value: minutes.toString(),
      );

  Future<int> getSyncFrequencyMinutes() async {
    final value = await _storage.read(key: AppConstants.keySyncFrequencyMinutes);
    return int.tryParse(value ?? '') ?? AppConstants.defaultSyncFrequencyMinutes;
  }
}
