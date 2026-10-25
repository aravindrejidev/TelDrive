import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/update_info.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../utils/helpers.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  ready,
  needsPermission,
  installing,
  error,
}

/// Everything about app updates: what is installed, whether something newer
/// exists, and how far a download has got. The update sheet and the Settings
/// screen both just read from here.
class UpdateProvider extends ChangeNotifier {
  final UpdateService _service = UpdateService.instance;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  AppVersion? currentVersion;

  /// Android's internal build number, shown next to the version in About.
  String currentBuild = '';
  UpdateInfo? info;

  /// Set when a check could not finish (offline, rate limited).
  String? checkError;

  /// Set when a download or install failed.
  String? errorMessage;

  double progress = 0;
  int receivedBytes = 0;
  int totalBytes = 0;
  double bytesPerSecond = 0;
  bool checksumVerified = false;

  File? _apk;
  DownloadHandle? _handle;
  bool _promptedThisSession = false;

  bool get isConfigured => _service.isConfigured;

  bool get isBusy =>
      _phase == UpdatePhase.downloading ||
      _phase == UpdatePhase.verifying ||
      _phase == UpdatePhase.installing;

  /// True while a newer version is known and has not been installed yet.
  bool get hasPendingUpdate =>
      info != null &&
      _phase != UpdatePhase.idle &&
      _phase != UpdatePhase.checking &&
      _phase != UpdatePhase.upToDate;

  Duration? get eta {
    if (bytesPerSecond < 1024 || totalBytes <= receivedBytes) return null;
    return Duration(seconds: ((totalBytes - receivedBytes) / bytesPerSecond).ceil());
  }

  Future<void>? _initFuture;

  /// Reads the installed version. Safe to call more than once; every check
  /// waits for it, so nothing runs before the version is known.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      final package = await PackageInfo.fromPlatform();
      currentVersion = AppVersion.tryParse(package.version);
      currentBuild = package.buildNumber;
    } catch (_) {}
    notifyListeners();
    final current = currentVersion;
    if (current != null) unawaited(_service.cleanOldDownloads(current));
  }

  /// Checks quietly when the app opens. Returns true when the update sheet
  /// should appear right now: a newer version exists, the person has not
  /// chosen to skip it, and it has not already been shown this session.
  Future<bool> checkOnStartup() async {
    if (_promptedThisSession || !isConfigured || isBusy) return false;
    final found = await _check(silent: true);
    final latest = info;
    if (!found || latest == null) return false;

    final skipped = await StorageService.instance.getSkippedUpdateVersion();
    if (skipped != null && skipped == latest.version.toString()) return false;

    _promptedThisSession = true;
    return true;
  }

  /// Checks because the person asked to. Returns true when an update exists.
  Future<bool> checkManually() async {
    if (isBusy) return info != null;
    return _check(silent: false);
  }

  Future<bool> _check({required bool silent}) async {
    await init();
    final wasPhase = _phase;
    if (!silent) {
      _phase = UpdatePhase.checking;
      checkError = null;
      notifyListeners();
    }

    try {
      final latest = await _service.fetchLatest();
      final current = currentVersion;
      if (latest != null && current != null && latest.version > current) {
        info = latest;
        checkError = null;
        // Keep going if a download is already underway or finished.
        if (!_hasProgress(wasPhase)) _phase = UpdatePhase.available;
        notifyListeners();
        return true;
      }
      info = null;
      _phase = UpdatePhase.upToDate;
      checkError = null;
      notifyListeners();
      return false;
    } on UpdateException catch (e) {
      if (!silent) {
        checkError = e.message;
        _phase = info != null ? UpdatePhase.available : UpdatePhase.idle;
        notifyListeners();
      } else if (_phase == UpdatePhase.checking) {
        _phase = UpdatePhase.idle;
      }
      return false;
    } catch (_) {
      if (!silent) {
        checkError = 'Could not check for updates.';
        _phase = UpdatePhase.idle;
        notifyListeners();
      }
      return false;
    }
  }

  bool _hasProgress(UpdatePhase phase) =>
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.ready ||
      phase == UpdatePhase.needsPermission ||
      phase == UpdatePhase.installing;

  Future<void> startDownload() async {
    final target = info;
    if (target == null || isBusy) return;

    final handle = DownloadHandle();
    _handle = handle;
    _phase = UpdatePhase.downloading;
    progress = 0;
    receivedBytes = 0;
    totalBytes = target.apkBytes;
    bytesPerSecond = 0;
    errorMessage = null;
    checksumVerified = false;
    notifyListeners();

    final clock = Stopwatch()..start();
    var lastTick = 0;
    var lastBytes = 0;

    try {
      final file = await _service.download(
        target,
        handle: handle,
        onProgress: (received, total) {
          receivedBytes = received;
          totalBytes = total > 0 ? total : target.apkBytes;
          progress = totalBytes > 0 ? (received / totalBytes).clamp(0.0, 1.0) : 0.0;

          final now = clock.elapsedMilliseconds;
          if (now - lastTick >= 350) {
            final instant = (received - lastBytes) * 1000 / (now - lastTick);
            bytesPerSecond =
                bytesPerSecond == 0 ? instant : bytesPerSecond * 0.7 + instant * 0.3;
            lastTick = now;
            lastBytes = received;
            notifyListeners();
          }
        },
      );

      _phase = UpdatePhase.verifying;
      progress = 1;
      notifyListeners();

      checksumVerified = await _service.verify(file, target);
      _apk = file;
      _phase = UpdatePhase.ready;
      notifyListeners();
    } on UpdateCancelled {
      _phase = UpdatePhase.available;
      progress = 0;
      notifyListeners();
    } on UpdateException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(friendlyError(e));
    } finally {
      _handle = null;
    }
  }

  void cancelDownload() => _handle?.cancel();

  /// Deletes downloaded update files. A finished download that has not been
  /// installed goes back to "available" so it can be downloaded again.
  Future<void> clearDownloads() async {
    if (isBusy) return;
    await _service.clearDownloads();
    _apk = null;
    if (_phase == UpdatePhase.ready ||
        _phase == UpdatePhase.needsPermission ||
        _phase == UpdatePhase.error) {
      _phase = info != null ? UpdatePhase.available : UpdatePhase.idle;
    }
    notifyListeners();
  }

  /// Lets the person be asked about a version they skipped before.
  Future<void> forgetSkippedVersion() async {
    await StorageService.instance.clearSkippedUpdateVersion();
    _promptedThisSession = false;
    notifyListeners();
  }

  /// Hands the downloaded APK to Android's installer, asking for the
  /// "install unknown apps" permission first if it is missing.
  Future<void> install() async {
    final file = _apk;
    if (file == null || !await file.exists()) {
      _apk = null;
      _fail('The downloaded file is gone. Download it again.');
      return;
    }

    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        _phase = UpdatePhase.needsPermission;
        notifyListeners();
        return;
      }
    }

    _phase = UpdatePhase.installing;
    notifyListeners();

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type == ResultType.permissionDenied) {
      _phase = UpdatePhase.needsPermission;
      notifyListeners();
      return;
    }
    if (result.type != ResultType.done) {
      _fail('Could not open the installer: ${result.message}');
      return;
    }

    // The installer is on screen. If the person backs out of it, the app is
    // still running, so offer to install again.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_phase == UpdatePhase.installing) {
      _phase = UpdatePhase.ready;
      notifyListeners();
    }
  }

  /// "Try again" after an error: re-run whichever step failed.
  Future<void> retry() => _apk != null ? install() : startDownload();

  Future<void> skipThisVersion() async {
    final latest = info;
    if (latest == null) return;
    await StorageService.instance.setSkippedUpdateVersion(latest.version.toString());
  }

  void _fail(String message) {
    errorMessage = message;
    _phase = UpdatePhase.error;
    notifyListeners();
  }
}
