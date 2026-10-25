import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import '../../utils/app_info.dart';
import '../../utils/formatters.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/update/update_sheet.dart';
import 'settings_widgets.dart';

class UpdatesSettingsScreen extends StatefulWidget {
  const UpdatesSettingsScreen({super.key});

  @override
  State<UpdatesSettingsScreen> createState() => _UpdatesSettingsScreenState();
}

class _UpdatesSettingsScreenState extends State<UpdatesSettingsScreen> {
  int _cachedBytes = 0;
  String? _skippedVersion;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes = await UpdateService.instance.cachedBytes();
    final skipped = await StorageService.instance.getSkippedUpdateVersion();
    if (!mounted) return;
    setState(() {
      _cachedBytes = bytes;
      _skippedVersion = skipped;
    });
  }

  String _status(UpdateProvider u) {
    if (!u.isConfigured) return 'Update checks are only available in release builds.';
    final version = u.info?.version;
    switch (u.phase) {
      case UpdatePhase.checking:
        return 'Checking for updates…';
      case UpdatePhase.upToDate:
        return 'You are on the latest version.';
      case UpdatePhase.available:
        return 'Version $version is available.';
      case UpdatePhase.downloading:
        return 'Downloading version $version, ${(u.progress * 100).round()}%.';
      case UpdatePhase.verifying:
        return 'Verifying the download…';
      case UpdatePhase.ready:
        return 'Version $version is downloaded and ready to install.';
      case UpdatePhase.needsPermission:
        return 'Version $version is ready. Android needs your permission to install it.';
      case UpdatePhase.installing:
        return 'Opening the installer…';
      case UpdatePhase.error:
        return u.errorMessage ?? 'The update did not finish.';
      case UpdatePhase.idle:
        return u.checkError ?? 'Tap below to check for updates.';
    }
  }

  Future<void> _onPrimary(UpdateProvider u) async {
    if (u.hasPendingUpdate) {
      showUpdateSheet(context);
      return;
    }
    final found = await u.checkManually();
    if (found && mounted) showUpdateSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateProvider>();
    final settings = context.watch<SettingsProvider>();
    final hasUpdate = u.hasPendingUpdate;
    final version = u.currentVersion;

    return SettingsPage(
      title: 'Updates',
      children: [
        const NeuSectionTitle('Status'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.system_update_rounded,
              title: version == null ? 'This version' : 'Installed: v$version',
              subtitle: _status(u),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: u.phase == UpdatePhase.downloading
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                      child: NeuProgressBar(value: u.progress, height: 12),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        SettingsButton(
          label: hasUpdate ? 'View update' : 'Check for updates',
          icon: hasUpdate ? Icons.rocket_launch_rounded : Icons.refresh_rounded,
          style: hasUpdate ? NeuButtonStyle.primary : NeuButtonStyle.secondary,
          loading: u.phase == UpdatePhase.checking,
          topGap: 14,
          onPressed: u.isConfigured ? () => _onPrimary(u) : null,
        ),
        const NeuSectionTitle('Automatic checks'),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: Icons.rocket_launch_rounded,
              title: 'Check when the app opens',
              subtitle: 'Show the update sheet if a newer version is out.',
              value: settings.autoCheckUpdates,
              onChanged: settings.setAutoCheckUpdates,
            ),
          ],
        ),
        const NeuSectionTitle('Downloads and skipped versions'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.folder_zip_rounded,
              title: 'Downloaded updates',
              subtitle: _cachedBytes > 0
                  ? Formatters.fileSize(_cachedBytes)
                  : 'Nothing stored',
            ),
            if (_skippedVersion != null)
              NeuListRow(
                icon: Icons.skip_next_rounded,
                title: 'Skipped version',
                subtitle: 'You chose to skip v$_skippedVersion.',
              ),
          ],
        ),
        SettingsButton(
          label: 'Clear downloaded updates',
          icon: Icons.cleaning_services_rounded,
          topGap: 14,
          onPressed: (_cachedBytes > 0 && !u.isBusy)
              ? () async {
                  await u.clearDownloads();
                  await _refresh();
                }
              : null,
        ),
        if (_skippedVersion != null)
          SettingsButton(
            label: 'Ask me about it again',
            icon: Icons.undo_rounded,
            topGap: 14,
            onPressed: () async {
              await u.forgetSkippedVersion();
              await _refresh();
            },
          ),
        const NeuSectionTitle('Source'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.hub_rounded,
              title: 'Checks releases of',
              subtitle: AppInfo.hasRepository
                  ? AppInfo.repository
                  : 'Not set in this build',
            ),
          ],
        ),
        const SettingsNote(
          'Updates come from this project\'s GitHub releases. Each download is '
          'checked against its published checksum, and Android only installs it '
          'if it is signed with the same key as the app you have.',
        ),
      ],
    );
  }
}
