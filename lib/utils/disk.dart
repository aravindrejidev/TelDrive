import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'constants.dart';

/// Where files downloaded from Telegram are kept on this device.
Future<Directory> downloadsDirectory() async {
  final base = await getApplicationDocumentsDirectory();
  return Directory(p.join(base.path, AppConstants.downloadsFolderName));
}

/// Total size in bytes of everything under [dir]; 0 if it does not exist.
Future<int> directorySize(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
  } catch (_) {}
  return total;
}

Future<void> deleteDirectory(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {}
}
