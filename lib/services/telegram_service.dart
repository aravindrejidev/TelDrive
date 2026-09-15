import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/file_item.dart';
import '../utils/constants.dart';

class TelegramApiException implements Exception {
  TelegramApiException(this.message, {this.errorCode});
  final String message;
  final int? errorCode;

  @override
  String toString() => message;
}

class TelegramUploadResult {
  TelegramUploadResult({
    required this.messageId,
    required this.fileId,
    required this.fileUniqueId,
    required this.fileSize,
  });

  final int messageId;
  final String fileId;
  final String? fileUniqueId;
  final int fileSize;
}

/// Every call this app makes to the Telegram Bot API.
///
/// A fresh instance is cheap to build (it just closes over the token and a
/// channel id), so callers construct one per target channel — this is what
/// lets one shared Bot Token fan out uploads across several channels.
class TelegramService {
  TelegramService({required this.botToken, required this.channelId});

  final String botToken;
  final String channelId;

  Uri _apiUri(String method, [Map<String, String>? query]) {
    final uri = Uri.parse('${AppConstants.telegramApiBase}/bot$botToken/$method');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeBody(String body) {
    late final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw TelegramApiException('Telegram returned an unexpected response.');
    }
    if (json['ok'] != true) {
      throw TelegramApiException(
        (json['description'] as String?) ?? 'Telegram API request failed.',
        errorCode: json['error_code'] as int?,
      );
    }
    return json;
  }

  Future<void> testConnection() async {
    final meResponse = await http.get(_apiUri('getMe'));
    _decodeBody(meResponse.body);

    final chatResponse = await http.get(_apiUri('getChat', {'chat_id': channelId}));
    try {
      _decodeBody(chatResponse.body);
    } on TelegramApiException catch (e) {
      throw TelegramApiException(
        'Bot token is valid, but the channel could not be reached: ${e.message}. '
        'Double-check the Channel ID and make sure the bot has been added to '
        'the channel as an admin.',
      );
    }
  }

  String _methodForCategory(FileCategory category) => switch (category) {
        FileCategory.photo => 'sendPhoto',
        FileCategory.video => 'sendVideo',
        FileCategory.audio => 'sendAudio',
        FileCategory.document => 'sendDocument',
      };

  String _fieldForCategory(FileCategory category) => switch (category) {
        FileCategory.photo => 'photo',
        FileCategory.video => 'video',
        FileCategory.audio => 'audio',
        FileCategory.document => 'document',
      };

  Future<TelegramUploadResult> uploadFile({
    required File file,
    required String fileName,
    required FileCategory category,
    void Function(int sent, int total)? onProgress,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _apiUri(_methodForCategory(category)),
    );
    request.fields['chat_id'] = channelId;
    request.fields['caption'] = fileName;
    request.files.add(
      await http.MultipartFile.fromPath(
        _fieldForCategory(category),
        file.path,
        filename: fileName,
      ),
    );

    final streamedResponse = await _sendMultipartWithProgress(request, onProgress);
    final body = await streamedResponse.stream.bytesToString();
    final json = _decodeBody(body);
    final result = json['result'] as Map<String, dynamic>;

    Map<String, dynamic>? mediaObject;
    switch (category) {
      case FileCategory.document:
        mediaObject = result['document'] as Map<String, dynamic>?;
      case FileCategory.video:
        mediaObject = result['video'] as Map<String, dynamic>?;
      case FileCategory.audio:
        mediaObject = result['audio'] as Map<String, dynamic>?;
      case FileCategory.photo:
        final sizes = result['photo'] as List<dynamic>?;
        if (sizes != null && sizes.isNotEmpty) {
          final sorted = List<Map<String, dynamic>>.from(sizes)
            ..sort(
              (a, b) => ((a['file_size'] as int?) ?? 0)
                  .compareTo((b['file_size'] as int?) ?? 0),
            );
          mediaObject = sorted.last;
        }
    }

    if (mediaObject == null) {
      throw TelegramApiException(
        'Telegram accepted the upload but the response was missing file details.',
      );
    }

    return TelegramUploadResult(
      messageId: result['message_id'] as int,
      fileId: mediaObject['file_id'] as String,
      fileUniqueId: mediaObject['file_unique_id'] as String?,
      fileSize: (mediaObject['file_size'] as int?) ?? await file.length(),
    );
  }

  Future<http.StreamedResponse> _sendMultipartWithProgress(
    http.MultipartRequest request,
    void Function(int sent, int total)? onProgress,
  ) async {
    final total = request.contentLength;
    final byteStream = request.finalize();

    final streamedRequest = http.StreamedRequest(request.method, request.url);
    streamedRequest.headers.addAll(request.headers);
    streamedRequest.contentLength = total;

    var bytesSent = 0;
    byteStream.listen(
      (chunk) {
        bytesSent += chunk.length;
        onProgress?.call(bytesSent, total);
        streamedRequest.sink.add(chunk);
      },
      onDone: streamedRequest.sink.close,
      onError: (Object error, StackTrace stackTrace) {
        streamedRequest.sink.addError(error, stackTrace);
      },
      cancelOnError: true,
    );

    return http.Client().send(streamedRequest);
  }

  Future<String> getFileDownloadUrl(String fileId) async {
    final response = await http.get(_apiUri('getFile', {'file_id': fileId}));
    final json = _decodeBody(response.body);
    final filePath = (json['result'] as Map<String, dynamic>)['file_path'] as String?;
    if (filePath == null) {
      throw TelegramApiException(
        'This file is larger than the 20 MB the Telegram Bot API allows bots '
        'to download, so it cannot be re-downloaded once the local copy is gone.',
      );
    }
    return '${AppConstants.telegramApiBase}/file/bot$botToken/$filePath';
  }

  Future<File> downloadFile({
    required String fileId,
    required String destinationPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = await getFileDownloadUrl(fileId);
    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw TelegramApiException(
        'Download failed (HTTP ${streamedResponse.statusCode}).',
      );
    }

    final total = streamedResponse.contentLength ?? 0;
    var received = 0;
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();

    await streamedResponse.stream
        .map((chunk) {
          received += chunk.length;
          onProgress?.call(received, total);
          return chunk;
        })
        .pipe(sink);

    return file;
  }

  Future<void> deleteMessage(int messageId) async {
    final response = await http.post(
      _apiUri('deleteMessage'),
      body: {'chat_id': channelId, 'message_id': messageId.toString()},
    );
    _decodeBody(response.body);
  }
}
