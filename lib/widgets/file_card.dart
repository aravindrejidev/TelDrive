import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../utils/file_type_helper.dart';
import '../utils/formatters.dart';

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.item, required this.onTap});

  final FileItem item;
  final VoidCallback onTap;

  bool get _hasLocalCopy => item.localPath != null && File(item.localPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = item.category == FileCategory.photo && _hasLocalCopy;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumbnail(item: item, isImage: isImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.fileSize(item.fileSizeBytes)} • ${Formatters.relativeTime(item.uploadedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(hasLocalCopy: _hasLocalCopy),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.isImage});

  final FileItem item;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = 52.0;
    final borderRadius = BorderRadius.circular(10);

    if (isImage) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(item.localPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 150,
          errorBuilder: (_, __, ___) => _iconBox(theme, size, borderRadius),
        ),
      );
    }
    return _iconBox(theme, size, borderRadius);
  }

  Widget _iconBox(ThemeData theme, double size, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: borderRadius,
      ),
      child: Icon(
        FileTypeHelper.iconForFile(item.fileName, item.category),
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.hasLocalCopy});

  final bool hasLocalCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasLocalCopy ? theme.colorScheme.tertiary : theme.colorScheme.outline;
    final icon = hasLocalCopy ? Icons.smartphone_rounded : Icons.cloud_done_rounded;
    final label = hasLocalCopy ? 'On this device' : 'On Telegram only';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
