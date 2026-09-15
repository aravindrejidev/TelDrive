import 'package:flutter/material.dart';
import 'app.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncService.instance.initialize();
  runApp(const TeleDriveApp());
}
