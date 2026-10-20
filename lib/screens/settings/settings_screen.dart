import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../models/sync_link.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../services/permission_service.dart';
import '../../services/sync_service.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_surface.dart';
import '../../widgets/update/update_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  int? _syncingLinkId;
  String? _syncMessage;
  bool _syncMessageIsError = false;

  static const _frequencyOptions = [15, 30, 60, 180, 360, 720, 1440];

  static String _frequencyLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    final days = minutes ~/ 1440;
    return days == 1 ? '1 day' : '$days days';
  }

  String _describe(SyncResult r) {
    if (r.busy) return 'A sync is already running. Try again in a moment.';

    final parts = <String>[
      if (r.uploaded > 0) '${r.uploaded} uploaded',
      if (r.failed > 0) '${r.failed} failed',
      if (r.tooLarge > 0) '${r.tooLarge} over the 50 MB limit',
      if (r.skipped > 0) '${r.skipped} will be retried later',
    ];
    if (parts.isEmpty) return r.lastError ?? 'Everything is already synced.';

    var text = '${parts.join(', ')}.';
    if (r.lastError != null) text = '$text ${r.lastError}';
    if (r.timedOut) text = '$text Some files are left for the next run.';
    return text;
  }

  Future<void> _runSync(Future<SyncResult> Function() action, {int? linkId}) async {
    final settings = context.read<SettingsProvider>();
    final files = context.read<FileProvider>();
    setState(() {
      _isSyncing = true;
      _syncingLinkId = linkId;
      _syncMessage = null;
    });
    try {
      final result = await action();
      await files.loadAll();
      await settings.refreshSyncLinks();
      if (!mounted) return;
      setState(() {
        _syncMessage = _describe(result);
        _syncMessageIsError = result.failed > 0 || result.lastError != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncMessage = friendlyError(e);
        _syncMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncingLinkId = null;
        });
      }
    }
  }

  Future<void> _signOut(SettingsProvider settings) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disconnect this bot?',
      message: 'You will need to enter the Bot Token and Channel ID again to use '
          '${AppConstants.appName}. Files already in Telegram are not touched.',
      confirmLabel: 'Disconnect',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (confirmed != true || !mounted) return;
    // The app gate swaps Home for the setup screen once the state changes, so
    // all that is left to do here is close Settings.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await settings.signOut();
  }

  Future<void> _openAddLinkDialog(SettingsProvider settings) async {
    await showNeuDialog<void>(
      context,
      builder: (_) => _AddSyncLinkDialog(settings: settings),
    );
  }

  Future<void> _removeLink(SettingsProvider settings, SyncLink link) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove "${link.name}"?',
      message: 'This stops syncing the folder. Files already uploaded stay in '
          'Telegram and in ${AppConstants.appName}.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed == true) await settings.removeSyncLink(link);
  }

  Future<void> _pickFrequency(SettingsProvider settings) async {
    final picked = await showNeuSheet<int>(
      context,
      builder: (sheetContext) {
        final c = sheetContext.neu;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Check for new files', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Android allows background checks at most every 15 minutes.',
              style: TextStyle(fontSize: 14, color: c.textMuted),
            ),
            const SizedBox(height: 10),
            for (final minutes in _frequencyOptions)
              NeuListRow(
                icon: Icons.timer_outlined,
                title: 'Every ${_frequencyLabel(minutes)}',
                trailing: minutes == settings.syncFrequencyMinutes
                    ? Icon(Icons.check_circle_rounded, color: c.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(minutes),
              ),
          ],
        );
      },
    );
    if (picked != null) await settings.setSyncFrequencyMinutes(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NeuPageHeader(
              title: 'Settings',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Consumer<SettingsProvider>(
                builder: (context, settings, _) => ListView(
                  padding: const EdgeInsets.only(bottom: 36),
                  children: [
                    const NeuSectionTitle('Telegram connection'),
                    _buildConnection(context, settings),
                    const NeuSectionTitle('Appearance and uploads'),
                    _buildPreferences(context, settings),
                    const NeuSectionTitle('Sync links'),
                    ..._buildSyncLinks(context, settings),
                    const NeuSectionTitle('Storage'),
                    _buildStorage(context),
                    const NeuSectionTitle('About and updates'),
                    _buildUpdates(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuSurface(
        radius: 28,
        distance: 7,
        blur: 16,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: child,
      ),
    );
  }

  Widget _buildConnection(BuildContext context, SettingsProvider settings) {
    final c = context.neu;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeuListRow(
            icon: Icons.key_rounded,
            title: 'Bot token',
            subtitle: _maskToken(settings.botToken),
          ),
          NeuListRow(
            icon: Icons.campaign_rounded,
            title: 'Main channel',
            subtitle: settings.channelId ?? 'Not set',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Text(
              'Uploads from the Photos, Videos, Audio and Documents tabs go here.',
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textMuted),
            ),
          ),
          NeuButton(
            label: 'Disconnect bot',
            icon: Icons.link_off_rounded,
            height: 50,
            style: NeuButtonStyle.danger,
            onPressed: () => _signOut(settings),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences(BuildContext context, SettingsProvider settings) {
    final c = context.neu;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Theme',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
            ),
          ),
          NeuSegmented<ThemeMode>(
            selected: settings.themeMode,
            onChanged: settings.setThemeMode,
            options: const [
              NeuSegment(
                value: ThemeMode.system,
                label: 'System',
                icon: Icons.brightness_auto_rounded,
              ),
              NeuSegment(
                value: ThemeMode.light,
                label: 'Light',
                icon: Icons.light_mode_rounded,
              ),
              NeuSegment(
                value: ThemeMode.dark,
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          NeuListRow(
            icon: Icons.high_quality_rounded,
            title: 'Original photo quality',
            subtitle: 'Sends photos as files so Telegram does not compress them.',
            trailing: NeuSwitch(
              value: settings.keepPhotoOriginal,
              onChanged: settings.setKeepPhotoOriginal,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSyncLinks(BuildContext context, SettingsProvider settings) {
    final c = context.neu;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
        child: Text(
          'Link a folder on this phone to a channel, for example a Music '
          'folder to a Music channel. New files upload on their own.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: c.textMuted),
        ),
      ),
      if (settings.syncLinks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: NeuSurface(
            depth: NeuDepth.inset,
            radius: 24,
            distance: 5,
            blur: 12,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.folder_off_rounded, color: c.textMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No sync links yet.',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
      else
        for (final link in settings.syncLinks)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _SyncLinkCard(
              link: link,
              syncing: _isSyncing && (_syncingLinkId == link.id || _syncingLinkId == null),
              busy: _isSyncing,
              onToggle: (enabled) => settings.setSyncLinkAutoSync(link, enabled),
              onRemove: () => _removeLink(settings, link),
              onSync: () => _runSync(
                () => SyncService.instance.runLinkNow(link),
                linkId: link.id,
              ),
            ),
          ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: NeuButton(
          label: 'Add sync link',
          icon: Icons.add_rounded,
          height: 52,
          style: NeuButtonStyle.secondary,
          onPressed: () => _openAddLinkDialog(settings),
        ),
      ),
      if (settings.hasAnyAutoSyncEnabled)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: NeuSurface(
            radius: 24,
            distance: 6,
            blur: 14,
            padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            child: NeuListRow(
              icon: Icons.timer_outlined,
              title: 'Check every ${_frequencyLabel(settings.syncFrequencyMinutes)}',
              subtitle: 'Applies to every link with auto-sync on.',
              trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
              onTap: () => _pickFrequency(settings),
            ),
          ),
        ),
      if (settings.syncLinks.isNotEmpty) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: NeuButton(
            label: (_isSyncing && _syncingLinkId == null) ? 'Syncing…' : 'Sync all now',
            icon: Icons.sync_rounded,
            loading: _isSyncing && _syncingLinkId == null,
            onPressed: _isSyncing
                ? null
                : () => _runSync(() => SyncService.instance.runAllLinksNow()),
          ),
        ),
      ],
      if (_syncMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: NeuSurface(
            depth: NeuDepth.inset,
            radius: 22,
            distance: 4,
            blur: 10,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _syncMessageIsError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: _syncMessageIsError ? c.danger : c.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _syncMessage!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: _syncMessageIsError ? c.danger : c.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildStorage(BuildContext context) {
    final c = context.neu;
    return Consumer<FileProvider>(
      builder: (context, files, _) {
        final total = files.totalBytes;
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              Text(
                Formatters.fileSize(total),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '${files.totalCount} files in Telegram',
                style: TextStyle(fontSize: 13.5, color: c.textMuted),
              ),
              const SizedBox(height: 18),
              for (final category in FileCategory.values)
                _StorageRow(
                  label: category.label,
                  stat: files.statsFor(category),
                  fraction: total == 0 ? 0 : files.statsFor(category).bytes / total,
                ),
            ],
          ),
        );
      },
    );
  }

  String _updateStatus(UpdateProvider u) {
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

  Future<void> _onUpdateButton(UpdateProvider u) async {
    if (u.hasPendingUpdate) {
      showUpdateSheet(context);
      return;
    }
    final found = await u.checkManually();
    if (found && mounted) showUpdateSheet(context);
  }

  Widget _buildUpdates(BuildContext context) {
    return Consumer<UpdateProvider>(
      builder: (context, u, _) {
        final hasUpdate = u.hasPendingUpdate;
        final checking = u.phase == UpdatePhase.checking;
        final version = u.currentVersion;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuListRow(
                icon: Icons.system_update_rounded,
                title: version == null
                    ? AppConstants.appName
                    : '${AppConstants.appName} $version',
                subtitle: _updateStatus(u),
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
              const SizedBox(height: 10),
              NeuButton(
                label: hasUpdate ? 'View update' : 'Check for updates',
                icon: hasUpdate ? Icons.rocket_launch_rounded : Icons.refresh_rounded,
                height: 50,
                style: hasUpdate ? NeuButtonStyle.primary : NeuButtonStyle.secondary,
                loading: checking,
                onPressed: u.isConfigured ? () => _onUpdateButton(u) : null,
              ),
            ],
          ),
        );
      },
    );
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'Not set';
    final colonIndex = token.indexOf(':');
    if (colonIndex == -1 || colonIndex + 5 > token.length) return '••••••••';
    return '${token.substring(0, colonIndex)}:${token.substring(colonIndex + 1, colonIndex + 5)}••••';
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.label, required this.stat, required this.fraction});

  final String label;
  final CategoryStat stat;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              Text(
                '${stat.count} files, ${Formatters.fileSize(stat.bytes)}',
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          NeuProgressBar(value: fraction, height: 10),
        ],
      ),
    );
  }
}

class _SyncLinkCard extends StatelessWidget {
  const _SyncLinkCard({
    required this.link,
    required this.syncing,
    required this.busy,
    required this.onToggle,
    required this.onRemove,
    required this.onSync,
  });

  final SyncLink link;
  final bool syncing;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final lastSynced = link.lastSyncedAt;

    return NeuSurface(
      radius: 28,
      distance: 7,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  link.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
                ),
              ),
              const SizedBox(width: 10),
              if (syncing)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent),
                    ),
                  ),
                )
              else
                NeuIconButton(
                  icon: Icons.sync_rounded,
                  size: 40,
                  iconSize: 19,
                  tooltip: 'Sync this link now',
                  onTap: busy ? null : onSync,
                ),
              const SizedBox(width: 10),
              NeuIconButton(
                icon: Icons.delete_outline_rounded,
                size: 40,
                iconSize: 19,
                color: c.danger,
                tooltip: 'Remove link',
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaLine(icon: Icons.folder_rounded, text: link.folderPath),
          _MetaLine(icon: Icons.campaign_rounded, text: link.channelId),
          _MetaLine(
            icon: Icons.schedule_rounded,
            text: lastSynced == null
                ? 'Not synced yet'
                : 'Synced ${Formatters.relativeTime(lastSynced)}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Auto-sync',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
                ),
              ),
              NeuSwitch(value: link.autoSyncEnabled, onChanged: onToggle),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSyncLinkDialog extends StatefulWidget {
  const _AddSyncLinkDialog({required this.settings});

  final SettingsProvider settings;

  @override
  State<_AddSyncLinkDialog> createState() => _AddSyncLinkDialogState();
}

class _AddSyncLinkDialogState extends State<_AddSyncLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _channelController = TextEditingController();
  String? _folderPath;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final hasAccess = await PermissionService.instance.hasAllFilesAccess();
    if (!hasAccess) {
      final granted = await PermissionService.instance.requestAllFilesAccess();
      if (!granted) {
        if (mounted) {
          setState(() => _errorMessage =
              'Allow access to all files so ${AppConstants.appName} can read the folder.');
        }
        return;
      }
    }
    final path = await FilePicker.getDirectoryPath();
    if (path != null && mounted) {
      setState(() {
        _folderPath = path;
        _errorMessage = null;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_folderPath == null) {
      setState(() => _errorMessage = 'Choose the folder to sync.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.settings.addSyncLink(
        name: _nameController.text,
        targetChannelId: _channelController.text,
        folderPath: _folderPath!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuDialogCard(
      title: 'Add sync link',
      icon: Icons.sync_alt_rounded,
      actions: [
        NeuButton(
          label: 'Cancel',
          height: 50,
          style: NeuButtonStyle.secondary,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        NeuButton(
          label: _isSaving ? 'Checking…' : 'Save',
          height: 50,
          loading: _isSaving,
          onPressed: _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeuTextField(
              controller: _nameController,
              label: 'Name',
              hint: 'Lossless music',
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this link a name' : null,
            ),
            const SizedBox(height: 16),
            NeuTextField(
              controller: _channelController,
              label: 'Channel',
              hint: '@my_music_channel or -100…',
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a channel username or ID' : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(
                'Add the bot to this channel as an admin that can post.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            NeuButton(
              label: _folderPath == null ? 'Choose folder' : 'Change folder',
              icon: Icons.folder_open_rounded,
              height: 48,
              style: NeuButtonStyle.secondary,
              onPressed: _pickFolder,
            ),
            if (_folderPath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                child: Text(
                  _folderPath!,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: c.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
