import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/neu_theme.dart';

/// How a surface sits relative to the page.
enum NeuDepth {
  /// Pushed out towards the viewer, with a shadow on each side.
  raised,

  /// Pressed into the page, with the shadows falling inside the edge.
  inset,

  /// Same material as the page with no shadow at all.
  flat,
}

/// The building block of the whole interface: a rounded patch of the base
/// material that is either [NeuDepth.raised] or [NeuDepth.inset].
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    this.child,
    this.depth = NeuDepth.raised,
    this.radius = 22,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.distance = 7,
    this.blur = 16,
    this.gradient,
  });

  final Widget? child;
  final NeuDepth depth;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double distance;
  final double blur;

  /// Overrides the default surface (or inset) gradient.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final content = padding == null ? child : Padding(padding: padding!, child: child);

    if (depth == NeuDepth.inset) {
      return Container(
        margin: margin,
        width: width,
        height: height,
        child: CustomPaint(
          painter: NeuInsetPainter(
            gradient: gradient ?? c.insetGradient,
            shadow: c.shadowDark,
            highlight: c.shadowLight,
            radius: radius,
            distance: distance,
            blur: blur,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ?? c.surfaceGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: depth == NeuDepth.raised
            ? c.raisedShadows(distance: distance, blur: blur)
            : null,
      ),
      child: content,
    );
  }
}

/// Paints a pressed-in surface.
///
/// Flutter has no inner shadow, so this fakes one: fill the shape, then clip
/// to it and draw a blurred "frame" (everything outside the shape) shifted
/// diagonally. The shifted frame falls across one inside edge as a shadow and,
/// shifted the opposite way, leaves a highlight on the other.
class NeuInsetPainter extends CustomPainter {
  const NeuInsetPainter({
    required this.gradient,
    required this.shadow,
    required this.highlight,
    required this.radius,
    required this.distance,
    required this.blur,
  });

  final Gradient gradient;
  final Color shadow;
  final Color highlight;
  final double radius;
  final double distance;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));

    final outer = Path()..addRect(rect.inflate(blur * 3 + distance * 2));
    final hole = Path()..addRRect(rrect);
    final frame = Path.combine(PathOperation.difference, outer, hole);
    final sigma = blur / 2;

    canvas.drawPath(
      frame.shift(Offset(distance, distance)),
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.drawPath(
      frame.shift(Offset(-distance, -distance)),
      Paint()
        ..color = highlight
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(NeuInsetPainter old) =>
      old.gradient != gradient ||
      old.shadow != shadow ||
      old.highlight != highlight ||
      old.radius != radius ||
      old.distance != distance ||
      old.blur != blur;
}
