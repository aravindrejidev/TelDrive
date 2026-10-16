import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../theme/neu_theme.dart';
import '../utils/file_type_helper.dart';
import '../utils/formatters.dart';
import 'neu/neu_controls.dart';
import 'neu/neu_surface.dart';

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.item, required this.onTap});

  final FileItem item;
  final VoidCallback onTap;

  bool get _hasLocalCopy => item.localPath != null && File(item.localPath!).existsSync();

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final hasLocal = _hasLocalCopy;
    final isImage = item.category == FileCategory.photo && hasLocal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: NeuTap(
        onTap: onTap,
        semanticLabel: item.fileName,
        builder: (context, pressed) => NeuSurface(
          depth: pressed ? NeuDepth.inset : NeuDepth.raised,
          radius: 26,
          distance: 6,
          blur: 14,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(item: item, showImage: isImage),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          Formatters.fileSize(item.fileSizeBytes),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            Formatters.relativeTime(item.uploadedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    NeuChip(
                      icon: hasLocal ? Icons.smartphone_rounded : Icons.cloud_done_rounded,
                      iconColor: hasLocal ? c.success : c.accent,
                      label: hasLocal ? 'On this device' : 'On Telegram only',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.showImage});

  final FileItem item;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final icon = Center(
      child: Icon(
        FileTypeHelper.iconForFile(item.fileName, item.category),
        size: 26,
        color: c.accent,
      ),
    );

    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 20,
      width: 60,
      height: 60,
      distance: 3,
      blur: 7,
      padding: const EdgeInsets.all(4),
      child: showImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(item.localPath!),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 160,
                errorBuilder: (_, __, ___) => icon,
              ),
            )
          : icon,
    );
  }
}
