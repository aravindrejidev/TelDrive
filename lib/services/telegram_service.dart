import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/file_item.dart';
import '../utils/constants.dart';
import '../utils/file_type_helper.dart';

class TelegramApiException implements Exception {
  TelegramApiException(this.message, {this.errorCode, this.retryAfterSeconds});

  final String message;
  final int? errorCode;

  /// Set when Telegram answers "Too Many Requests"; the number of seconds to
  /// wait before trying again.
  final int? retryAfterSeconds;

  /// Deleting a message that is already gone is a success as far as the user
  /// is concerned.
  bool get isMessageNotFound {
    final lower = message.toLowerCase();
    return lower.contains('message to delete not found') ||
        lower.contains('message not found');
  }

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
/// channel id), so callers construct one per target channel - this is what
/// lets one shared Bot Token fan out uploads across several channels.
class TelegramService {
  TelegramService({required this.botToken, required this.channelId});

  final String botToken;
  final String channelId;

  static const Duration _apiTimeout = Duration(seconds: 30);
  static const int _maxRateLimitRetries = 3;
  static const int _maxPhotoBytes = 10 * 1024 * 1024; // sendPhoto limit

  static const Set<String> _nativePhotoExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Uri _apiUri(String method, [Map<String, String>? query]) {
    final uri = Uri.parse('${AppConstants.telegramApiBase}/bot$botToken/$method');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeBody(String body) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      json = decoded;
    } catch (_) {
      throw TelegramApiException('Telegram returned an unexpected response.');
    }
    if (json['ok'] != true) {
      final params = json['parameters'];
      final retryAfter = params is Map ? params['retry_after'] : null;
      throw TelegramApiException(
        (json['description'] as String?) ?? 'Telegram API request failed.',
        errorCode: json['error_code'] as int?,
        retryAfterSeconds: retryAfter is int ? retryAfter : null,
      );
    }
    return json;
  }

  /// Runs [action] and turns network-level failures into a readable
  /// [TelegramApiException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      throw TelegramApiException(
        'Telegram did not respond in time. Check your connection and try again.',
      );
    } on SocketException {
      throw TelegramApiException('Could not reach Telegram. Check your internet connection.');
    } on http.ClientException {
      throw TelegramApiException('Could not reach Telegram. Check your internet connection.');
    }
  }

  /// One short API call. A new client per call, always closed, so no sockets
  /// are left open.
  Future<Map<String, dynamic>> _call(
    String method, {
    Map<String, String>? query,
    Map<String, String>? form,
  }) {
    return _guard(() async {
      final client = http.Client();
      try {
        final response = form == null
            ? await client.get(_apiUri(method, query)).timeout(_apiTimeout)
            : await client.post(_apiUri(method), body: form).timeout(_apiTimeout);
        return _decodeBody(utf8.decode(response.bodyBytes, allowMalformed: true));
      } finally {
        client.close();
      }
    });
  }

  /// Checks the token, that the channel is reachable, and that the bot is
  /// allowed to post there - so a wrong setup is reported immediately instead
  /// of as a failed upload later.
  Future<void> testConnection() async {
    final Map<String, dynamic> me;
    try {
      me = await _call('getMe');
    } on TelegramApiException catch (e) {
      if (e.errorCode == 401) {
        throw TelegramApiException(
          'Telegram rejected this Bot Token. Copy it again from @BotFather.',
          errorCode: 401,
        );
      }
      rethrow;
    }
    final botId = (me['result'] as Map<String, dynamic>)['id'];

    try {
      await _call('getChat', query: {'chat_id': channelId});
    } on TelegramApiException catch (e) {
      throw TelegramApiException(
        'The token is valid, but the channel could not be reached: ${e.message}. '
        'Check the Channel ID and make sure the bot is an admin of the channel.',
      );
    }

    Map<String, dynamic>? member;
    try {
      final response = await _call(
        'getChatMember',
        query: {'chat_id': channelId, 'user_id': '$botId'},
      );
      member = response['result'] as Map<String, dynamic>?;
    } on TelegramApiException {
      member = null; // Could not check - the first upload will tell.
    }
    if (member != null) {
      final status = member['status'];
      if (status != 'administrator' && status != 'creator') {
        throw TelegramApiException(
          'The bot is in the channel but is not an admin. Add it as an admin '
          'that can post messages.',
        );
      }
      if (status == 'administrator' && member['can_post_messages'] == false) {
        throw TelegramApiException(
          'The bot is an admin but is not allowed to post. Turn on "Post '
          'messages" for it in the channel\'s admin settings.',
        );
      }
    }
  }

  // --- uploading -----------------------------------------------------------

  /// Picks the Bot API method for a file.
  ///
  /// Only the formats Telegram natively supports use the typed methods
  /// (sendPhoto: jpg/png/webp up to 10 MB; sendVideo: mp4; sendAudio:
  /// mp3/m4a). Everything else - FLAC, WAV, MKV, HEIC and so on - goes out as
  /// a document, which keeps the file byte-for-byte intact.
  ({String method, String field}) _routeFor(
    FileCategory category,
    String fileName,
    int size,
    bool keepPhotoOriginal,
  ) {
    const document = (method: 'sendDocument', field: 'document');
    final ext = FileTypeHelper.extensionOf(fileName);
    switch (category) {
      case FileCategory.photo:
        final native = !keepPhotoOriginal &&
            size <= _maxPhotoBytes &&
            _nativePhotoExtensions.contains(ext);
        return native ? (method: 'sendPhoto', field: 'photo') : document;
      case FileCategory.video:
        return ext == 'mp4' ? (method: 'sendVideo', field: 'video') : document;
      case FileCategory.audio:
        return (ext == 'mp3' || ext == 'm4a')
            ? (method: 'sendAudio', field: 'audio')
            : document;
      case FileCategory.document:
        return document;
    }
  }

  /// Uploads [file]. Rate-limit responses (HTTP 429) are waited out and the
  /// upload is retried automatically a few times.
  Future<TelegramUploadResult> uploadFile({
    required File file,
    required String fileName,
    required FileCategory category,
    bool keepPhotoOriginal = true,
    bool silent = true,
    void Function(int sent, int total)? onProgress,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _uploadOnce(
          file: file,
          fileName: fileName,
          category: category,
          keepPhotoOriginal: keepPhotoOriginal,
          silent: silent,
          onProgress: onProgress,
        );
      } on TelegramApiException catch (e) {
        final wait = e.retryAfterSeconds;
        if (wait == null || attempt >= _maxRateLimitRetries) rethrow;
        await Future<void>.delayed(Duration(seconds: wait + 1));
      }
    }
  }

  Future<TelegramUploadResult> _uploadOnce({
    required File file,
    required String fileName,
    required FileCategory category,
    required bool keepPhotoOriginal,
    required bool silent,
    void Function(int sent, int total)? onProgress,
  }) {
    return _guard(() async {
      final size = await file.length();
      final route = _routeFor(category, fileName, size, keepPhotoOriginal);

      final request = http.MultipartRequest('POST', _apiUri(route.method));
      request.fields['chat_id'] = channelId;
      request.fields['caption'] =
          fileName.length > 1000 ? fileName.substring(0, 1000) : fileName;
      // A big sync would otherwise ping everyone who follows the channel.
      if (silent) request.fields['disable_notification'] = 'true';
      if (route.method == 'sendDocument') {
        request.fields['disable_content_type_detection'] = 'true';
      }
      if (route.method == 'sendVideo') {
        request.fields['supports_streaming'] = 'true';
      }
      request.files.add(
        await http.MultipartFile.fromPath(route.field, file.path, filename: fileName),
      );

      final client = http.Client();
      try {
        final streamed = await _sendWithProgress(client, request, onProgress)
            .timeout(const Duration(minutes: 20));
        final bytes = await streamed.stream.toBytes();
        final json = _decodeBody(utf8.decode(bytes, allowMalformed: true));

        final result = json['result'] as Map<String, dynamic>;
        final media = _extractMedia(result);
        if (media == null) {
          throw TelegramApiException(
            'Telegram accepted the upload but the response was missing file details.',
          );
        }
        return TelegramUploadResult(
          messageId: (result['message_id'] as num).toInt(),
          fileId: media['file_id'] as String,
          fileUniqueId: media['file_unique_id'] as String?,
          fileSize: (media['file_size'] as num?)?.toInt() ?? size,
        );
      } finally {
        client.close();
      }
    });
  }

  /// Telegram may answer with a different media type than the method we
  /// called (for example a `document` for a video it could not parse), so
  /// look at everything rather than only the expected key.
  Map<String, dynamic>? _extractMedia(Map<String, dynamic> message) {
    final photo = message['photo'];
    if (photo is List && photo.isNotEmpty) {
      final sizes = photo.whereType<Map<String, dynamic>>().toList();
      if (sizes.isNotEmpty) {
        num weight(Map<String, dynamic> m) =>
            (m['file_size'] as num?) ??
            (((m['width'] as num?) ?? 0) * ((m['height'] as num?) ?? 0));
        sizes.sort((a, b) => weight(a).compareTo(weight(b)));
        return sizes.last;
      }
    }
    for (final key in const ['document', 'video', 'audio', 'animation', 'voice', 'video_note']) {
      final value = message[key];
      if (value is Map<String, dynamic>) return value;
    }
    return null;
  }

  /// Streams the multipart body and reports progress as the HTTP client
  /// actually pulls it, so the bar tracks real network progress instead of
  /// racing ahead while the whole file sits in memory.
  Future<http.StreamedResponse> _sendWithProgress(
    http.Client client,
    http.MultipartRequest request,
    void Function(int sent, int total)? onProgress,
  ) {
    final total = request.contentLength;
    final body = request.finalize();

    final streamed = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = total;

    final response = client.send(streamed);

    var sent = 0;
    final counted = body.map((chunk) {
      sent += chunk.length;
      onProgress?.call(sent, total);
      return chunk;
    });
    unawaited(
      streamed.sink
          .addStream(counted)
          .then((_) => streamed.sink.close())
          .catchError((Object error, StackTrace stackTrace) {
        streamed.sink.addError(error, stackTrace);
        streamed.sink.close();
      }),
    );
    return response;
  }

  // --- downloading ---------------------------------------------------------

  static const String _tooBigMessage =
      'This file is larger than 20 MB, the most a bot can download. '
      'Open it from the Telegram app instead.';

  Future<String> getFileDownloadUrl(String fileId) async {
    final Map<String, dynamic> json;
    try {
      json = await _call('getFile', query: {'file_id': fileId});
    } on TelegramApiException catch (e) {
      if (e.message.toLowerCase().contains('file is too big')) {
        throw TelegramApiException(_tooBigMessage, errorCode: e.errorCode);
      }
      rethrow;
    }
    final filePath = (json['result'] as Map<String, dynamic>)['file_path'] as String?;
    if (filePath == null) throw TelegramApiException(_tooBigMessage);
    return '${AppConstants.telegramApiBase}/file/bot$botToken/$filePath';
  }

  /// Downloads to a temporary `.part` file and renames it when complete, so a
  /// failed or interrupted download never leaves a broken file behind.
  Future<File> downloadFile({
    required String fileId,
    required String destinationPath,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = await getFileDownloadUrl(fileId);
    final partial = File('$destinationPath.part');

    return _guard(() async {
      final client = http.Client();
      try {
        final response = await client
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw TelegramApiException('Download failed (HTTP ${response.statusCode}).');
        }

        final total = response.contentLength ?? 0;
        var received = 0;
        await partial.parent.create(recursive: true);
        final sink = partial.openWrite();
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (total > 0 && received != total) {
          throw TelegramApiException('The download was interrupted. Try again.');
        }

        final target = File(destinationPath);
        if (await target.exists()) await target.delete();
        return await partial.rename(destinationPath);
      } catch (_) {
        if (await partial.exists()) {
          try {
            await partial.delete();
          } catch (_) {}
        }
        rethrow;
      } finally {
        client.close();
      }
    });
  }

  Future<void> deleteMessage(int messageId) async {
    await _call(
      'deleteMessage',
      form: {'chat_id': channelId, 'message_id': messageId.toString()},
    );
  }
}
