/// A named pairing of one device folder with one Telegram channel.
///
/// The app can hold any number of these. Every Sync Link with
/// [autoSyncEnabled] set to true is scanned on each background sync cycle;
/// any file found in [folderPath] that hasn't been uploaded before (tracked
/// in the `files` table) gets uploaded to [channelId], using the single
/// shared Bot Token from Settings. This is what lets one bot fan out to
/// several channels — e.g. a "Lossless Music" link watching a Music folder
/// and posting to a dedicated Music channel, alongside the original Camera
/// folder posting to a separate channel.
class SyncLink {
  const SyncLink({
    this.id,
    required this.name,
    required this.channelId,
    required this.folderPath,
    this.autoSyncEnabled = false,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String channelId;
  final String folderPath;
  final bool autoSyncEnabled;
  final DateTime createdAt;

  SyncLink copyWith({
    int? id,
    String? name,
    String? channelId,
    String? folderPath,
    bool? autoSyncEnabled,
    DateTime? createdAt,
  }) {
    return SyncLink(
      id: id ?? this.id,
      name: name ?? this.name,
      channelId: channelId ?? this.channelId,
      folderPath: folderPath ?? this.folderPath,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'channel_id': channelId,
      'folder_path': folderPath,
      'auto_sync_enabled': autoSyncEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncLink.fromMap(Map<String, Object?> map) {
    return SyncLink(
      id: map['id'] as int?,
      name: map['name'] as String,
      channelId: map['channel_id'] as String,
      folderPath: map['folder_path'] as String,
      autoSyncEnabled: (map['auto_sync_enabled'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
