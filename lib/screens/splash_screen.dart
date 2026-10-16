import 'package:flutter/material.dart';
import '../theme/neu_theme.dart';
import '../utils/constants.dart';
import '../widgets/neu/neu_controls.dart';
import '../widgets/neu/neu_surface.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NeuSurface(
              radius: 99,
              width: 112,
              height: 112,
              distance: 10,
              blur: 24,
              child: Center(child: GradientIcon(Icons.cloud_rounded, size: 54)),
            ),
            const SizedBox(height: 28),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
