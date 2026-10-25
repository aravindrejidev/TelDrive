import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sync_link.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/permission_service.dart';
import '../../services/sync_service.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_surface.dart';
import 'settings_widgets.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
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
              SettingsChoiceRow(
                icon: Icons.timer_outlined,
                title: 'Every ${_frequencyLabel(minutes)}',
                selected: minutes == settings.syncFrequencyMinutes,
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
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final c = context.neu;
        return SettingsPage(
          title: 'Sync',
          children: [
            const SettingsNote(
              'Link a folder on this phone to a channel, for example a Music '
              'folder to a Music channel. New files upload on their own.',
            ),
            const SizedBox(height: 14),
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
              Column(
                children: [
                  for (final link in settings.syncLinks)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _SyncLinkCard(
                        link: link,
                        syncing: _isSyncing &&
                            (_syncingLinkId == link.id || _syncingLinkId == null),
                        busy: _isSyncing,
                        onToggle: (enabled) => settings.setSyncLinkAutoSync(link, enabled),
                        onRemove: () => _removeLink(settings, link),
                        onSync: () => _runSync(
                          () => SyncService.instance.runLinkNow(link),
                          linkId: link.id,
                        ),
                      ),
                    ),
                ],
              ),
            SettingsButton(
              label: 'Add sync link',
              icon: Icons.add_rounded,
              topGap: 4,
              onPressed: () => _openAddLinkDialog(settings),
            ),
            const NeuSectionTitle('Schedule'),
            SettingsCard(
              children: [
                NeuListRow(
                  icon: Icons.timer_outlined,
                  title: 'Check every ${_frequencyLabel(settings.syncFrequencyMinutes)}',
                  subtitle: 'Applies to every link with auto-sync on.',
                  trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
                  onTap: () => _pickFrequency(settings),
                ),
              ],
            ),
            const NeuSectionTitle('Only sync when'),
            SettingsCard(
              children: [
                SettingsSwitchRow(
                  icon: Icons.wifi_rounded,
                  title: 'Connected to Wi-Fi',
                  subtitle: 'Never use mobile data for background syncing.',
                  value: settings.syncWifiOnly,
                  onChanged: settings.setSyncWifiOnly,
                ),
                SettingsSwitchRow(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Charging',
                  subtitle: 'Wait until the phone is plugged in.',
                  value: settings.syncOnlyCharging,
                  onChanged: settings.setSyncOnlyCharging,
                ),
                SettingsSwitchRow(
                  icon: Icons.battery_5_bar_rounded,
                  title: 'Battery is not low',
                  subtitle: 'Skip syncing when the battery is running down.',
                  value: settings.syncBatteryNotLow,
                  onChanged: settings.setSyncBatteryNotLow,
                ),
              ],
            ),
            const SettingsNote(
              'These only affect automatic syncing in the background. '
              '"Sync now" always runs straight away.',
            ),
            if (settings.syncLinks.isNotEmpty)
              SettingsButton(
                label: (_isSyncing && _syncingLinkId == null) ? 'Syncing…' : 'Sync all now',
                icon: Icons.sync_rounded,
                style: NeuButtonStyle.primary,
                loading: _isSyncing && _syncingLinkId == null,
                topGap: 22,
                onPressed: _isSyncing
                    ? null
                    : () => _runSync(() => SyncService.instance.runAllLinksNow()),
              ),
            if (_syncMessage != null)
              SettingsMessage(text: _syncMessage!, isError: _syncMessageIsError),
          ],
        );
      },
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
