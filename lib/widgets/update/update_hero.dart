import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../providers/update_provider.dart';
import '../../theme/neu_theme.dart';
import '../neu/neu_controls.dart';
import '../neu/neu_surface.dart';

/// The round badge at the top of the update sheet.
///
/// A glow behind it breathes, a ring around it fills as the download
/// progresses, and the icon inside swaps with a pop whenever the stage
/// changes (rocket, download arrow, shield, tick, and so on).
class UpdateHero extends StatelessWidget {
  const UpdateHero({
    super.key,
    required this.phase,
    required this.progress,
    required this.pulse,
  });

  final UpdatePhase phase;
  final double progress;

  /// A 0 to 1 value that loops back and forth to drive the breathing.
  final Animation<double> pulse;

  static const double _size = 156;

  bool get _showsRing =>
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.verifying ||
      phase == UpdatePhase.ready ||
      phase == UpdatePhase.installing;

  double get _ringValue => switch (phase) {
        UpdatePhase.downloading => progress,
        UpdatePhase.verifying ||
        UpdatePhase.ready ||
        UpdatePhase.installing =>
          1.0,
        _ => 0.0,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final tone = phase == UpdatePhase.error ? c.danger : c.accent;

    return SizedBox(
      width: _size,
      height: _size,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(pulse.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              // The breathing glow.
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tone.withValues(alpha: 0.14 + 0.14 * t),
                      blurRadius: 34 + 24 * t,
                      spreadRadius: 2 + 7 * t,
                    ),
                  ],
                ),
              ),
              // The progress ring.
              AnimatedOpacity(
                opacity: _showsRing ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _ringValue),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    size: const Size.square(_size),
                    painter: _RingPainter(
                      value: value,
                      track: c.shadowDark.withValues(alpha: 0.4),
                      from: c.accent,
                      to: c.accentDeep,
                    ),
                  ),
                ),
              ),
              // The badge.
              NeuSurface(
                radius: 99,
                width: 104,
                height: 104,
                distance: 9,
                blur: 20,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 480),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey<UpdatePhase>(phase),
                      child: _icon(c, t),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _icon(NeuColors c, double t) {
    switch (phase) {
      case UpdatePhase.downloading:
        // The arrow dips and rises like it is dropping the file in.
        return Transform.translate(
          offset: Offset(0, -5 + 10 * t),
          child: const GradientIcon(Icons.arrow_downward_rounded, size: 46),
        );
      case UpdatePhase.verifying:
        return const GradientIcon(Icons.verified_user_rounded, size: 44);
      case UpdatePhase.ready:
        return Icon(Icons.check_rounded, size: 56, color: c.success);
      case UpdatePhase.needsPermission:
        return const GradientIcon(Icons.lock_open_rounded, size: 44);
      case UpdatePhase.installing:
        return const GradientIcon(Icons.install_mobile_rounded, size: 44);
      case UpdatePhase.error:
        return Icon(Icons.error_outline_rounded, size: 50, color: c.danger);
      default:
        // The rocket hovers gently while the update waits to be started.
        return Transform.translate(
          offset: Offset(0, 3 - 6 * t),
          child: const GradientIcon(Icons.rocket_launch_rounded, size: 46),
        );
    }
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.from,
    required this.to,
  });

  final double value;
  final Color track;
  final Color from;
  final Color to;

  static const double _stroke = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track,
    );

    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [from, to, from],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.from != from || old.to != to;
}
