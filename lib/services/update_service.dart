import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/update_info.dart';

/// A problem the person can be told about in plain words.
class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the person cancels a download.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Lets the screen stop a download that is in progress.
class DownloadHandle {
  bool _cancelled = false;
  http.Client? _client;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close();
  }
}

/// Finds new releases on GitHub and downloads them.
///
/// The repository comes from `--dart-define=GITHUB_REPO=owner/name`, which the
/// release workflow sets automatically. A local debug build has no value, so
/// update checks stay switched off there.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String repository = String.fromEnvironment('GITHUB_REPO');

  bool get isConfigured => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repository);

  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Only ever download from GitHub itself.
  bool _isTrustedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host;
    return host == 'github.com' ||
        host.endsWith('.github.com') ||
        host.endsWith('.githubusercontent.com');
  }

  /// The newest published release that has an APK, or null when there is
  /// none yet. Pre-releases and drafts are never returned by this endpoint.
  Future<UpdateInfo?> fetchLatest() async {
    if (!isConfigured) return null;
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.https('api.github.com', '/repos/$repository/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'TeleDrive-Updater',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 404) return null;
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw UpdateException(
          'GitHub is limiting requests right now. Try again in a little while.',
        );
      }
      if (response.statusCode != 200) {
        throw UpdateException(
          'Could not check for updates (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return _parse(decoded);
    } on TimeoutException {
      throw UpdateException('Checking for updates timed out. Check your connection.');
    } on SocketException {
      throw UpdateException('No internet connection.');
    } on http.ClientException {
      throw UpdateException('No internet connection.');
    } on FormatException {
      throw UpdateException('GitHub sent a reply the app could not read.');
    } finally {
      client.close();
    }
  }

  UpdateInfo? _parse(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    final version = tag == null ? null : AppVersion.tryParse(tag);
    if (tag == null || version == null) return null;

    final assets = (json['assets'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
        const <Map<String, dynamic>>[];

    Map<String, dynamic>? apk;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apk = asset;
        break;
      }
    }
    if (apk == null) return null;

    final apkName = p.basename(apk['name'] as String);
    final apkUrl = apk['browser_download_url'] as String?;
    if (apkUrl == null || !_isTrustedUrl(apkUrl)) return null;

    // GitHub reports a digest for uploaded assets; a `.sha256` file attached
    // by the workflow is the fallback.
    String? sha;
    final digest = apk['digest'] as String?;
    if (digest != null && digest.toLowerCase().startsWith('sha256:')) {
      final candidate = digest.substring(7).toLowerCase();
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(candidate)) sha = candidate;
    }

    String? shaUrl;
    for (final asset in assets) {
      if ((asset['name'] as String? ?? '') == '$apkName.sha256') {
        final url = asset['browser_download_url'] as String?;
        if (url != null && _isTrustedUrl(url)) shaUrl = url;
      }
    }

    return UpdateInfo(
      version: version,
      tag: tag,
      notes: (json['body'] as String?) ?? '',
      apkName: apkName,
      apkUrl: apkUrl,
      apkBytes: (apk['size'] as num?)?.toInt() ?? 0,
      pageUrl: (json['html_url'] as String?) ?? '',
      sha256: sha,
      sha256Url: shaUrl,
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
    );
  }

  Future<Directory> _updateDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'teledrive_updates'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Downloads the APK. A complete copy from an earlier attempt is reused.
  /// The file is written under a temporary name and only renamed once it is
  /// whole, so a half-finished download is never mistaken for a good one.
  Future<File> download(
    UpdateInfo info, {
    required DownloadHandle handle,
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await _updateDir();
    final target = File(p.join(dir.path, info.apkName));
    final partial = File('${target.path}.part');

    if (await target.exists()) {
      final length = await target.length();
      if (info.apkBytes > 0 && length == info.apkBytes) {
        onProgress(length, length);
        return target;
      }
      await target.delete();
    }

    final client = http.Client();
    handle._client = client;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(info.apkUrl)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw UpdateException(
          'The download server answered with an error (HTTP ${response.statusCode}).',
        );
      }

      final total = (response.contentLength ?? 0) > 0
          ? response.contentLength!
          : info.apkBytes;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (handle.isCancelled) throw const UpdateCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (info.apkBytes > 0 && received != info.apkBytes) {
        throw UpdateException('The download was incomplete. Try again.');
      }
      return await partial.rename(target.path);
    } catch (error) {
      await _deleteQuietly(partial);
      if (handle.isCancelled) throw const UpdateCancelled();
      if (error is UpdateException || error is UpdateCancelled) rethrow;
      if (error is TimeoutException) {
        throw UpdateException('The connection timed out. Try again.');
      }
      if (error is SocketException || error is http.ClientException) {
        throw UpdateException('The download was interrupted. Check your connection.');
      }
      rethrow;
    } finally {
      client.close();
      handle._client = null;
    }
  }

  /// Compares the file against the published SHA-256. Returns true when it
  /// matched and false when the release published no checksum to compare
  /// with. Throws, and deletes the file, when it does not match.
  Future<bool> verify(File file, UpdateInfo info) async {
    final expected = await _expectedChecksum(info);
    if (expected == null) return false;

    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString().toLowerCase() != expected) {
      await _deleteQuietly(file);
      throw UpdateException(
        'The downloaded file did not match its checksum, so it was discarded. Try again.',
      );
    }
    return true;
  }

  Future<String?> _expectedChecksum(UpdateInfo info) async {
    if (info.sha256 != null) return info.sha256;
    final url = info.sha256Url;
    if (url == null) return null;

    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(url)).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final match = RegExp(r'\b[0-9a-fA-F]{64}\b').firstMatch(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      return match?.group(0)?.toLowerCase();
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Deletes leftovers from earlier updates: partial downloads and APKs of
  /// versions that are already installed.
  Future<void> cleanOldDownloads(AppVersion current) async {
    try {
      final dir = await _updateDir();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final version = AppVersion.tryParse(name);
        if (name.endsWith('.part') || version == null || !(version > current)) {
          await _deleteQuietly(entity);
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
