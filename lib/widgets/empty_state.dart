import 'package:flutter/material.dart';
import '../theme/neu_theme.dart';
import 'neu/neu_controls.dart';
import 'neu/neu_surface.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuSurface(
              depth: NeuDepth.inset,
              radius: 99,
              width: 118,
              height: 118,
              distance: 7,
              blur: 16,
              child: Center(child: GradientIcon(icon, size: 46)),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14.5, height: 1.45, color: c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
