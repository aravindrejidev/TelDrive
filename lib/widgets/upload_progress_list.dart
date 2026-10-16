import 'package:flutter/material.dart';
import '../providers/upload_provider.dart';
import '../theme/neu_theme.dart';
import '../utils/formatters.dart';
import 'neu/neu_controls.dart';
import 'neu/neu_surface.dart';

class UploadProgressList extends StatelessWidget {
  const UploadProgressList({
    super.key,
    required this.tasks,
    required this.onDismiss,
    required this.onRetry,
  });

  final List<UploadTask> tasks;
  final void Function(String id) onDismiss;
  final void Function(String id) onRetry;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => _UploadCard(
          task: tasks[index],
          onDismiss: () => onDismiss(tasks[index].id),
          onRetry: () => onRetry(tasks[index].id),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.task,
    required this.onDismiss,
    required this.onRetry,
  });

  final UploadTask task;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  String get _statusText => switch (task.status) {
        UploadTaskStatus.queued => 'Waiting in line',
        UploadTaskStatus.uploading =>
          '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}% of ${Formatters.fileSize(task.totalBytes)}',
        UploadTaskStatus.success => 'Uploaded, ${Formatters.fileSize(task.totalBytes)}',
        UploadTaskStatus.failed => task.errorMessage ?? 'Upload failed',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final failed = task.status == UploadTaskStatus.failed;
    final success = task.status == UploadTaskStatus.success;

    return NeuSurface(
      width: 244,
      radius: 24,
      distance: 5,
      blur: 12,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              if (task.isFinished)
                _MiniAction(
                  icon: Icons.close_rounded,
                  tooltip: 'Dismiss',
                  onTap: onDismiss,
                )
              else
                const SizedBox(height: 32),
            ],
          ),
          if (failed) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _statusText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: c.danger,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 12, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 16, color: c.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeuProgressBar(value: success ? 1 : task.progress, height: 11),
                  const SizedBox(height: 8),
                  Text(
                    _statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: context.neu.textMuted),
        ),
      ),
    );
  }
}
