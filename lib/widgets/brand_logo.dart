import 'package:flutter/material.dart';
import '../theme/neu_theme.dart';

/// The TeleDrive app icon, drawn the same way everywhere in the app.
///
/// [glow] adds a soft blue halo like the neon in the artwork. [raised] adds the
/// app's usual two-sided neumorphic shadow, which suits the light and dark
/// pages; turn it off on a fixed dark background such as the splash screen,
/// where a light shadow would look like a stray white smudge.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 56,
    this.glow = false,
    this.raised = true,
  });

  static const String asset = 'assets/branding/logo.png';

  final double size;
  final bool glow;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          if (raised) ...c.raisedShadows(distance: size * 0.08, blur: size * 0.22),
          if (glow)
            BoxShadow(
              color: const Color(0xFF00A3FF).withValues(alpha: 0.42),
              blurRadius: size * 0.4,
              spreadRadius: size * 0.02,
              offset: Offset(0, size * 0.1),
            ),
        ],
      ),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        semanticLabel: 'TeleDrive logo',
      ),
    );
  }
}
