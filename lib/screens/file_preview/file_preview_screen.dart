import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../../services/telegram_service.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/file_type_helper.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_surface.dart';

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
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  bool get _hasLocalCopy => _item.localPath != null && File(_item.localPath!).existsSync();

  bool get _tooBigToRedownload => _item.fileSizeBytes > AppConstants.maxRedownloadBytes;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFile() async {
    if (!_hasLocalCopy) return;
    final result = await OpenFilex.open(_item.localPath!);
    if (result.type != ResultType.done && mounted) {
      _showSnack('Could not open the file: ${result.message}');
    }
  }

  Future<void> _openInTelegram() async {
    final primary = context.read<SettingsProvider>().channelId;
    final uri = telegramMessageUri(_item.channelId ?? primary, _item.telegramMessageId);
    if (uri == null) {
      _showSnack('This channel has no link that can be opened. Open it in Telegram yourself.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showSnack('Could not open Telegram.');
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final botToken = await StorageService.instance.getBotToken();
      // Downloading via getFile only needs the Bot Token and the file_id, so
      // the primary channel id is just a harmless placeholder here.
      final channelId = await StorageService.instance.getChannelId();
      if (botToken == null || channelId == null) {
        throw AppException('Telegram credentials are missing.');
      }

      final telegram = TelegramService(botToken: botToken, channelId: channelId);
      final baseDir = await getApplicationDocumentsDirectory();
      // One folder per file keeps two files with the same name apart.
      final destinationPath = p.join(
        baseDir.path,
        'TeleDrive',
        _item.category.dbValue,
        '${_item.id ?? _item.telegramMessageId}',
        sanitizeFileName(_item.fileName),
      );

      await telegram.downloadFile(
        fileId: _item.telegramFileId,
        destinationPath: destinationPath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      await context.read<FileProvider>().setLocalPath(_item, destinationPath);
      if (!mounted) return;
      setState(() {
        _item = _item.copyWith(localPath: destinationPath);
        _statusMessage = 'Saved on this device.';
        _statusIsError = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = friendlyError(e);
          _statusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _deleteFile() async {
    final choice = await showNeuSheet<String>(
      context,
      builder: (sheetContext) {
        final c = sheetContext.neu;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Delete this file?', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Choose where to remove it from.',
              style: TextStyle(fontSize: 14, color: c.textMuted),
            ),
            const SizedBox(height: 10),
            NeuListRow(
              icon: Icons.visibility_off_rounded,
              title: 'Remove from TeleDrive only',
              subtitle: 'The message stays in your Telegram channel.',
              onTap: () => Navigator.of(sheetContext).pop('app'),
            ),
            NeuListRow(
              icon: Icons.delete_forever_rounded,
              tone: c.danger,
              title: 'Delete permanently',
              subtitle: 'Also deletes the message from Telegram.',
              onTap: () => Navigator.of(sheetContext).pop('permanent'),
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) return;

    if (choice == 'permanent') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete permanently?',
        message: 'This also removes the file from your Telegram channel. '
            'You cannot undo it.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed != true || !mounted) return;
    }

    await _performDelete(permanent: choice == 'permanent');
  }

  Future<void> _performDelete({required bool permanent}) async {
    final files = context.read<FileProvider>();
    try {
      await files.deleteFile(_item, alsoDeleteFromTelegram: permanent);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (!permanent) {
        _showSnack(friendlyError(e));
        return;
      }
      final removeAnyway = await showConfirmDialog(
        context,
        title: 'Could not delete from Telegram',
        message: '${friendlyError(e)}\n\nRemove it from TeleDrive only instead? '
            'The message will stay in your channel.',
        confirmLabel: 'Remove from app',
      );
      if (removeAnyway == true && mounted) {
        await _performDelete(permanent: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final hasLocal = _hasLocalCopy;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NeuPageHeader(
              title: 'File details',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreview(hasLocal),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        _item.fileName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeuSurface(
                      depth: NeuDepth.inset,
                      radius: 26,
                      distance: 5,
                      blur: 12,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Size',
                            value: Formatters.fileSize(_item.fileSizeBytes),
                          ),
                          _InfoRow(label: 'Type', value: _item.category.label),
                          _InfoRow(
                            label: 'Uploaded',
                            value: Formatters.dateTime(_item.uploadedAt),
                          ),
                          _InfoRow(
                            label: 'Stored',
                            value: hasLocal ? 'Device and Telegram' : 'Telegram only',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isDownloading) ...[
                      NeuProgressBar(value: _downloadProgress),
                      const SizedBox(height: 10),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_statusMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: _statusIsError ? c.danger : c.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!hasLocal && _tooBigToRedownload)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        child: Text(
                          'Telegram only lets bots download files up to 20 MB, '
                          'so this one cannot be saved back to the phone from '
                          'here. You can still open it in Telegram.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, height: 1.45, color: c.textMuted),
                        ),
                      ),
                    ..._buildActions(hasLocal),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(bool hasLocal) {
    final openInTelegram = NeuButton(
      label: 'Open in Telegram',
      icon: Icons.send_rounded,
      style: (!hasLocal && _tooBigToRedownload)
          ? NeuButtonStyle.primary
          : NeuButtonStyle.secondary,
      onPressed: _openInTelegram,
    );

    return [
      if (hasLocal)
        NeuButton(label: 'Open file', icon: Icons.open_in_new_rounded, onPressed: _openFile)
      else if (!_tooBigToRedownload)
        NeuButton(
          label: _isDownloading ? 'Downloading…' : 'Download',
          icon: Icons.download_rounded,
          loading: _isDownloading,
          onPressed: _downloadFile,
        ),
      if (hasLocal || !_tooBigToRedownload) const SizedBox(height: 16),
      openInTelegram,
      const SizedBox(height: 16),
      NeuButton(
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        style: NeuButtonStyle.danger,
        onPressed: _deleteFile,
      ),
    ];
  }

  Widget _buildPreview(bool hasLocal) {
    final showImage = _item.category == FileCategory.photo && hasLocal;
    final iconPlaceholder = Center(
      child: GradientIcon(
        FileTypeHelper.iconForFile(_item.fileName, _item.category),
        size: 72,
      ),
    );

    return NeuSurface(
      radius: 36,
      distance: 9,
      blur: 22,
      height: 250,
      padding: const EdgeInsets.all(14),
      child: NeuSurface(
        depth: NeuDepth.inset,
        radius: 26,
        distance: 5,
        blur: 12,
        padding: const EdgeInsets.all(6),
        child: showImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(_item.localPath!),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => iconPlaceholder,
                ),
              )
            : iconPlaceholder,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textMuted),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}
