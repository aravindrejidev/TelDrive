/// The tabs the Home screen organizes uploaded files into.
enum FileCategory { photo, video, audio, document }

extension FileCategoryX on FileCategory {
  String get dbValue => switch (this) {
        FileCategory.photo => 'photo',
        FileCategory.video => 'video',
        FileCategory.audio => 'audio',
        FileCategory.document => 'document',
      };

  String get label => switch (this) {
        FileCategory.photo => 'Photos',
        FileCategory.video => 'Videos',
        FileCategory.audio => 'Audio',
        FileCategory.document => 'Documents',
      };

  static FileCategory fromDbValue(String value) => switch (value) {
        'photo' => FileCategory.photo,
        'video' => FileCategory.video,
        'audio' => FileCategory.audio,
        _ => FileCategory.document,
      };
}

/// The status of a single row's upload lifecycle.
enum UploadStatus { uploaded, uploading, failed }

extension UploadStatusX on UploadStatus {
  String get dbValue => switch (this) {
        UploadStatus.uploaded => 'uploaded',
        UploadStatus.uploading => 'uploading',
        UploadStatus.failed => 'failed',
      };

  static UploadStatus fromDbValue(String value) => switch (value) {
        'uploading' => UploadStatus.uploading,
        'failed' => UploadStatus.failed,
        _ => UploadStatus.uploaded,
      };
}

/// A single file tracked by the app.
///
/// [channelId] records which Telegram channel this particular file lives in
/// — needed now that a file can come from any of several Sync Links (each
/// pointing at its own channel) or from a manual upload to the primary
/// channel. A `null` value means "the primary channel from Settings",
/// which is what every row created before multi-channel support existed
/// implicitly means.
class FileItem {
  const FileItem({
    this.id,
    required this.fileName,
    required this.telegramFileId,
    this.telegramUniqueId,
    required this.telegramMessageId,
    required this.category,
    required this.fileSizeBytes,
    this.mimeType,
    this.localPath,
    required this.uploadedAt,
    this.status = UploadStatus.uploaded,
    this.channelId,
  });

  final int? id;
  final String fileName;
  final String telegramFileId;
  final String? telegramUniqueId;
  final int telegramMessageId;
  final FileCategory category;
  final int fileSizeBytes;
  final String? mimeType;
  final String? localPath;
  final DateTime uploadedAt;
  final UploadStatus status;
  final String? channelId;

  FileItem copyWith({
    int? id,
    String? fileName,
    String? telegramFileId,
    String? telegramUniqueId,
    int? telegramMessageId,
    FileCategory? category,
    int? fileSizeBytes,
    String? mimeType,
    bool clearLocalPath = false,
    String? localPath,
    DateTime? uploadedAt,
    UploadStatus? status,
    String? channelId,
  }) {
    return FileItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      telegramFileId: telegramFileId ?? this.telegramFileId,
      telegramUniqueId: telegramUniqueId ?? this.telegramUniqueId,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      category: category ?? this.category,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      uploadedAt: uploadedAt ?? this.uploadedAt,
      status: status ?? this.status,
      channelId: channelId ?? this.channelId,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'telegram_file_id': telegramFileId,
      'telegram_unique_id': telegramUniqueId,
      'telegram_message_id': telegramMessageId,
      'category': category.dbValue,
      'file_size': fileSizeBytes,
      'mime_type': mimeType,
      'local_path': localPath,
      'uploaded_at': uploadedAt.toIso8601String(),
      'status': status.dbValue,
      'channel_id': channelId,
    };
  }

  factory FileItem.fromMap(Map<String, Object?> map) {
    return FileItem(
      id: map['id'] as int?,
      fileName: map['file_name'] as String,
      telegramFileId: map['telegram_file_id'] as String,
      telegramUniqueId: map['telegram_unique_id'] as String?,
      telegramMessageId: map['telegram_message_id'] as int,
      category: FileCategoryX.fromDbValue(map['category'] as String),
      fileSizeBytes: map['file_size'] as int? ?? 0,
      mimeType: map['mime_type'] as String?,
      localPath: map['local_path'] as String?,
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
      status: UploadStatusX.fromDbValue(map['status'] as String? ?? 'uploaded'),
      channelId: map['channel_id'] as String?,
    );
  }
}
