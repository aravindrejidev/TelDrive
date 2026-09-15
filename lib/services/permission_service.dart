import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._internal();
  static final PermissionService instance = PermissionService._internal();

  Future<bool> requestMediaAccess() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();
    return statuses.values.any((status) => status.isGranted);
  }

  Future<bool> hasMediaAccess() async {
    if (!Platform.isAndroid) return true;
    final photos = await Permission.photos.status;
    final videos = await Permission.videos.status;
    return photos.isGranted || videos.isGranted;
  }

  Future<bool> requestAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) return true;
    return Permission.manageExternalStorage.status.isGranted;
  }

  Future<bool> openSettings() => openAppSettings();
}
