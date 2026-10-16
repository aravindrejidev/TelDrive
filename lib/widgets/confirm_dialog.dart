import 'package:flutter/material.dart';
import '../theme/neu_theme.dart';
import 'neu/neu_controls.dart';

Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  IconData? icon,
}) {
  return showNeuDialog<bool>(
    context,
    builder: (dialogContext) {
      final c = dialogContext.neu;
      return NeuDialogCard(
        title: title,
        icon: icon ??
            (destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded),
        iconColor: destructive ? c.danger : c.accent,
        child: Text(
          message,
          style: TextStyle(fontSize: 14.5, height: 1.5, color: c.textMuted),
        ),
        actions: [
          NeuButton(
            label: 'Cancel',
            height: 50,
            style: NeuButtonStyle.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          NeuButton(
            label: confirmLabel,
            height: 50,
            style: destructive ? NeuButtonStyle.danger : NeuButtonStyle.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
}
