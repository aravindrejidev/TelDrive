import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Eases its child into place (a fade and a small rise) after a delay that
/// grows with [index], so a column of rows appears one after another.
class NeuReveal extends StatefulWidget {
  const NeuReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 55),
  });

  final Widget child;
  final int index;
  final Duration step;

  @override
  State<NeuReveal> createState() => _NeuRevealState();
}

class _NeuRevealState extends State<NeuReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Later rows share the last delay, so a long list never feels slow.
    final delay = widget.step * math.min(widget.index, 9) + const Duration(milliseconds: 40);
    _timer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eased = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: eased.drive(
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero),
        ),
        child: widget.child,
      ),
    );
  }
}
