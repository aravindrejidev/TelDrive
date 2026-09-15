import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../services/storage_service.dart';
import '../../services/telegram_service.dart';
import '../../utils/constants.dart';
import '../../utils/file_type_helper.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';

class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({super.key, required this.item});

  final FileItem item;

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late FileItem _item;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  bool get _hasLocalCopy => _item.localPath != null && File(_item.localPath!).existsSync();

  Future<void> _openFile() async {
    if (!_hasLocalCopy) return;
    final result = await OpenFilex.open(_item.localPath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = null;
    });

    try {
      final botToken = await StorageService.instance.getBotToken();
      // Downloading via getFile only needs the Bot Token + file_id, not a
      // channel id, so the primary channel id here is just a harmless
      // placeholder to satisfy the constructor.
      final channelId = await StorageService.instance.getChannelId();
      if (botToken == null || channelId == null) {
        throw Exception('Telegram credentials are missing.');
      }

      final telegram = TelegramService(botToken: botToken, channelId: channelId);
      final downloadsDir = await getApplicationDocumentsDirectory();
      final destinationPath =
          '${downloadsDir.path}/TeleDrive/${_item.category.dbValue}/${_item.fileName}';

      await telegram.downloadFile(
        fileId: _item.telegramFileId,
        destinationPath: destinationPath,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      final fileProvider = context.read<FileProvider>();
      await fileProvider.setLocalPath(_item, destinationPath);
      setState(() {
        _item = _item.copyWith(localPath: destinationPath);
        _statusMessage = 'Downloaded successfully.';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _deleteFile() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Delete this file?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('app_only'),
            child: const ListTile(
              leading: Icon(Icons.remove_circle_outline_rounded),
              title: Text('Remove from TeleDrive only'),
              subtitle: Text('Keeps the message in your Telegram channel'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('permanent'),
            child: ListTile(
              leading: Icon(Icons.delete_forever_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete permanently',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('Also deletes the message from Telegram'),
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'permanent') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete permanently?',
        message:
            'This removes the file from your Telegram channel too. This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    await context.read<FileProvider>().deleteFile(
          _item,
          alsoDeleteFromTelegram: choice == 'permanent',
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_item.fileName, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPreview(theme),
            const SizedBox(height: 24),
            _InfoRow(label: 'Size', value: Formatters.fileSize(_item.fileSizeBytes)),
            _InfoRow(label: 'Category', value: _item.category.label),
            _InfoRow(label: 'Uploaded', value: Formatters.dateTime(_item.uploadedAt)),
            _InfoRow(
              label: 'Location',
              value: _hasLocalCopy ? 'On this device + Telegram' : 'Telegram only',
            ),
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (_statusMessage != null) ...[
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
            ],
            if (!_hasLocalCopy && _item.fileSizeBytes > AppConstants.maxRedownloadBytes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This file is larger than 20 MB. The Telegram Bot API only '
                  'allows bots to download files up to 20 MB, so re-downloading '
                  'it here may not be possible — you can still open it directly '
                  'in the Telegram app.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_hasLocalCopy)
              FilledButton.icon(
                onPressed: _openFile,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open'),
              )
            else
              FilledButton.icon(
                onPressed: _isDownloading ? null : _downloadFile,
                icon: const Icon(Icons.download_rounded),
                label: Text(_isDownloading ? 'Downloading…' : 'Download'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _deleteFile,
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              label: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    if (_item.category == FileCategory.photo && _hasLocalCopy) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(File(_item.localPath!), fit: BoxFit.cover, height: 220),
      );
    }
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        FileTypeHelper.iconForFile(_item.fileName, _item.category),
        size: 64,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
