import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../services/database_service.dart';
import '../../theme/neu_theme.dart';
import '../../utils/disk.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/neu/neu_controls.dart';
import 'settings_widgets.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  int? _downloadedBytes;
  int? _removedCount;
  bool _clearing = false;
  bool _purging = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes = await directorySize(await downloadsDirectory());
    final removed = await DatabaseService.instance.removedCount();
    if (!mounted) return;
    setState(() {
      _downloadedBytes = bytes;
      _removedCount = removed;
    });
  }

  Future<void> _clearDownloads() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear downloaded copies?',
      message: 'This frees ${Formatters.fileSize(_downloadedBytes ?? 0)} on this phone. '
          'The files stay in Telegram and can be downloaded again.',
      confirmLabel: 'Clear',
      destructive: true,
      icon: Icons.cleaning_services_rounded,
    );
    if (confirmed != true || !mounted) return;

    final files = context.read<FileProvider>();
    final freed = _downloadedBytes ?? 0;
    setState(() {
      _clearing = true;
      _message = null;
    });
    final dir = await downloadsDirectory();
    await DatabaseService.instance.clearLocalPathsUnder(dir.path);
    await deleteDirectory(dir);
    await files.loadAll();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _message = 'Freed ${Formatters.fileSize(freed)}.';
    });
  }

  Future<void> _forgetRemoved() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Forget removed files?',
      message: 'TeleDrive remembers files you removed so that sync does not upload '
          'them again. If you forget them, any that are still in a sync folder '
          'will be uploaded again.',
      confirmLabel: 'Forget',
      destructive: true,
      icon: Icons.history_toggle_off_rounded,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _purging = true;
      _message = null;
    });
    final count = await DatabaseService.instance.purgeRemoved();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _purging = false;
      _message = 'Forgot $count removed ${count == 1 ? 'file' : 'files'}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final files = context.watch<FileProvider>();
    final total = files.totalBytes;
    final hasDownloads = (_downloadedBytes ?? 0) > 0;
    final removed = _removedCount ?? 0;

    return SettingsPage(
      title: 'Storage and data',
      children: [
        const NeuSectionTitle('In Telegram'),
        SettingsCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          children: [
            Text(
              Formatters.fileSize(total),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${files.totalCount} files',
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
        const NeuSectionTitle('On this phone'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.download_done_rounded,
              title: 'Downloaded copies',
              subtitle: _downloadedBytes == null
                  ? 'Measuring…'
                  : hasDownloads
                      ? '${Formatters.fileSize(_downloadedBytes!)} saved from Telegram'
                      : 'Nothing downloaded',
            ),
          ],
        ),
        SettingsButton(
          label: _clearing ? 'Clearing…' : 'Clear downloaded copies',
          icon: Icons.cleaning_services_rounded,
          loading: _clearing,
          topGap: 14,
          onPressed: hasDownloads && !_clearing ? _clearDownloads : null,
        ),
        const SettingsNote(
          'Only files you downloaded inside TeleDrive. Files in your sync '
          'folders are never touched.',
        ),
        const NeuSectionTitle('Removed files'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.visibility_off_rounded,
              title: 'Remembered so sync skips them',
              subtitle: _removedCount == null
                  ? 'Counting…'
                  : removed == 0
                      ? 'No removed files'
                      : '$removed removed ${removed == 1 ? 'file' : 'files'}',
            ),
          ],
        ),
        SettingsButton(
          label: _purging ? 'Working…' : 'Forget removed files',
          icon: Icons.history_toggle_off_rounded,
          loading: _purging,
          topGap: 14,
          onPressed: removed > 0 && !_purging ? _forgetRemoved : null,
        ),
        if (_message != null) SettingsMessage(text: _message!),
      ],
    );
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
