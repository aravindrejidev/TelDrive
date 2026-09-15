import 'package:flutter/material.dart';
import '../providers/upload_provider.dart';
import '../utils/formatters.dart';

class UploadProgressList extends StatelessWidget {
  const UploadProgressList({super.key, required this.tasks, required this.onDismiss});

  final List<UploadTask> tasks;
  final void Function(String id) onDismiss;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _UploadCard(
          task: tasks[index],
          onDismiss: () => onDismiss(tasks[index].id),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.task, required this.onDismiss});

  final UploadTask task;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = task.status == UploadTaskStatus.failed;
    final isSuccess = task.status == UploadTaskStatus.success;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: isFailed
            ? Border.all(color: theme.colorScheme.error.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (isSuccess || isFailed)
                InkWell(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 16),
                  ),
                ),
            ],
          ),
          if (isFailed)
            Text(
              task.errorMessage ?? 'Upload failed',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isSuccess ? 1 : task.progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuccess
                  ? 'Uploaded • ${Formatters.fileSize(task.totalBytes)}'
                  : '${(task.progress * 100).clamp(0, 100).toStringAsFixed(0)}% of ${Formatters.fileSize(task.totalBytes)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
