import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../models/sync_link.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/permission_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../onboarding/setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  String? _syncResultMessage;

  static const _frequencyOptions = [15, 30, 60, 180, 360, 720, 1440];

  String _frequencyLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    if (minutes < 1440) return '${minutes ~/ 60} hour${minutes >= 120 ? 's' : ''}';
    return '${minutes ~/ 1440} day${minutes >= 2880 ? 's' : ''}';
  }

  Future<void> _syncNow() async {
    setState(() {
      _isSyncing = true;
      _syncResultMessage = null;
    });
    final result = await SyncService.instance.runAllLinksNow()
    if (!mounted) return;
    await context.read<FileProvider>().loadAll();
    setState(() {
      _isSyncing = false;
      _syncResultMessage = result.totalConsidered == 0
          ? 'No new files found across your Sync Links.'
          : 'Uploaded ${result.uploaded}, failed ${result.failed}, skipped ${result.skipped}.';
    });
  }

  Future<void> _signOut(SettingsProvider settings) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disconnect this bot?',
      message: 'You\'ll need to re-enter your Bot Token and Channel ID to use '
          'TeleDrive again. Files already uploaded to Telegram are not affected.',
      confirmLabel: 'Disconnect',
      destructive: true,
    );
    if (confirmed != true) return;
    await settings.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _openAddLinkDialog(SettingsProvider settings) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddSyncLinkDialog(settings: settings),
    );
  }

  Future<void> _removeLink(SettingsProvider settings, SyncLink link) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove "${link.name}"?',
      message: 'This stops syncing this folder. Files already uploaded through '
          'it stay in Telegram and in TeleDrive.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed == true) {
      await settings.removeSyncLink(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            children: [
              const _SectionHeader('Telegram Connection'),
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Bot Token'),
                subtitle: Text(_maskToken(settings.botToken)),
              ),
              ListTile(
                leading: const Icon(Icons.campaign_rounded),
                title: const Text('Primary Channel ID'),
                subtitle: Text(settings.channelId ?? '—'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Used for manual uploads from the Photos/Videos/Audio/Documents tabs.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(settings),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Disconnect Bot'),
                ),
              ),
              const Divider(),
              const _SectionHeader('Sync Links'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Link any number of device folders to their own Telegram '
                  'channels — e.g. a Music folder to a Music channel — and '
                  'each syncs independently in the background.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              if (settings.syncLinks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text('No Sync Links yet.'),
                )
              else
                ...settings.syncLinks.map(
                  (link) => _SyncLinkTile(
                    link: link,
                    onToggle: (enabled) => settings.setSyncLinkAutoSync(link, enabled),
                    onRemove: () => _removeLink(settings, link),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _openAddLinkDialog(settings),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Sync Link'),
                ),
              ),
              if (settings.hasAnyAutoSyncEnabled)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Sync Frequency'),
                  subtitle: const Text('Applies to every Sync Link with Auto-Sync on'),
                  trailing: DropdownButton<int>(
                    value: settings.syncFrequencyMinutes,
                    items: _frequencyOptions
                        .map((m) => DropdownMenuItem(value: m, child: Text(_frequencyLabel(m))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) settings.setSyncFrequencyMinutes(value);
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.tonalIcon(
                  onPressed: (settings.syncLinks.isEmpty || _isSyncing) ? null : _syncNow,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_isSyncing ? 'Syncing…' : 'Sync Now (all links)'),
                ),
              ),
              if (_syncResultMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _syncResultMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(),
              const _SectionHeader('Storage Overview'),
              FutureBuilder(
                future: context.read<FileProvider>().getCounts(),
                builder: (context, snapshot) {
                  final counts = snapshot.data;
                  if (counts == null) return const SizedBox.shrink();
                  return Column(
                    children: counts.entries
                        .map((e) => ListTile(
                              dense: true,
                              title: Text(e.key.label),
                              trailing: Text('${e.value}'),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return '—';
    final colonIndex = token.indexOf(':');
    if (colonIndex == -1 || colonIndex + 5 > token.length) return '••••••••';
    return '${token.substring(0, colonIndex)}:${token.substring(colonIndex + 1, colonIndex + 5)}••••';
  }
}

class _SyncLinkTile extends StatelessWidget {
  const _SyncLinkTile({required this.link, required this.onToggle, required this.onRemove});

  final SyncLink link;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(link.name, style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              link.folderPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '→ ${link.channelId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Auto-Sync'),
              value: link.autoSyncEnabled,
              onChanged: onToggle,
            ),
          ],
        ),
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
      if (!granted) return;
    }
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _folderPath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_folderPath == null) {
      setState(() => _errorMessage = 'Please select a folder to sync.');
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
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Sync Link'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name (e.g. Lossless Music)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _channelController,
                decoration: const InputDecoration(
                  labelText: 'Target Channel ID',
                  hintText: '@my_music_channel or -100...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 4),
              Text(
                'Make sure the bot is also added as admin to this channel.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(_folderPath == null ? 'Select Folder' : 'Change Folder'),
              ),
              if (_folderPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _folderPath!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
