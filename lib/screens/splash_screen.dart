import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/brand_logo.dart';

/// The first screen, shown while the saved settings are read.
///
/// It is always dark navy, whatever theme the person chose, so it continues
/// the native Android launch screen without a flash of another colour.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Color _navy = Color(0xFF0B1220);
  static const Color _deepBlue = Color(0xFF0A2A66);
  static const Color _cyan = Color(0xFF00D1FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navy, _navy, _deepBlue],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 116, glow: true, raised: false),
                const SizedBox(height: 28),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Telegram. Backed up. Always.',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9FB6D9),
                  ),
                ),
                const SizedBox(height: 34),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: _cyan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
