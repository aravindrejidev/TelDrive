import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/neu/neu_route.dart';
import 'about_screen.dart';
import 'appearance_settings_screen.dart';
import 'connection_settings_screen.dart';
import 'library_settings_screen.dart';
import 'settings_widgets.dart';
import 'storage_settings_screen.dart';
import 'sync_settings_screen.dart';
import 'updates_settings_screen.dart';
import 'uploads_settings_screen.dart';

/// The Settings home: one card per area. Tapping a card opens that area's own
/// screen, so each page only has the settings that belong together.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(neuRoute(page));

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Follows your phone',
        ThemeMode.light => 'Light theme',
        ThemeMode.dark => 'Dark theme',
      };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final files = context.watch<FileProvider>();
    final updates = context.watch<UpdateProvider>();

    final links = settings.syncLinks;
    final autoOn = links.where((l) => l.autoSyncEnabled).length;
    final syncSummary = links.isEmpty
        ? 'No sync links yet'
        : '${links.length} ${links.length == 1 ? 'link' : 'links'}, '
            '${autoOn == 0 ? 'auto-sync off' : 'auto-sync on for $autoOn'}';

    final updateSummary = updates.hasPendingUpdate
        ? 'Version ${updates.info?.version} is available'
        : updates.phase == UpdatePhase.upToDate
            ? 'You are up to date'
            : 'Check for a newer version';

    final version = updates.currentVersion;

    return SettingsPage(
      title: 'Settings',
      children: [
        SettingsTile(
          icon: Icons.palette_rounded,
          title: 'Appearance',
          subtitle: '${_themeName(settings.themeMode)}, ${settings.accentPalette.label} accent',
          onTap: () => _open(context, const AppearanceSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.folder_copy_rounded,
          title: 'Library',
          subtitle: '${settings.defaultSort.label}, opens on ${kTabNames[settings.startTabIndex]}',
          onTap: () => _open(context, const LibrarySettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.cloud_upload_rounded,
          title: 'Uploads',
          subtitle: '${settings.keepPhotoOriginal ? 'Original photos' : 'Compressed photos'}, '
              '${settings.maxConcurrentUploads} at a time',
          onTap: () => _open(context, const UploadsSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.sync_alt_rounded,
          title: 'Sync',
          subtitle: syncSummary,
          onTap: () => _open(context, const SyncSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.storage_rounded,
          title: 'Storage and data',
          subtitle: '${files.totalCount} files, ${Formatters.fileSize(files.totalBytes)} in Telegram',
          onTap: () => _open(context, const StorageSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.send_rounded,
          title: 'Telegram connection',
          subtitle: settings.channelId ?? 'Not connected',
          onTap: () => _open(context, const ConnectionSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.system_update_rounded,
          title: 'Updates',
          subtitle: updateSummary,
          badge: updates.hasPendingUpdate,
          onTap: () => _open(context, const UpdatesSettingsScreen()),
        ),
        SettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: version == null
              ? AppConstants.appName
              : '${AppConstants.appName} v$version',
          onTap: () => _open(context, const AboutScreen()),
        ),
      ],
    );
  }
}
