import 'package:flutter/material.dart';

/// Page transition used for Settings: the new page slides in from the right
/// while fading up, and the page underneath drifts left and dims a little, so
/// moving between screens has a sense of depth instead of a hard cut.
Route<T> neuRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final enter = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
        position: secondaryAnimation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        ).drive(Tween<Offset>(begin: Offset.zero, end: const Offset(-0.08, 0))),
        child: FadeTransition(
          opacity: secondaryAnimation.drive(Tween<double>(begin: 1, end: 0.55)),
          child: SlideTransition(
            position: enter.drive(
              Tween<Offset>(begin: const Offset(0.14, 0), end: Offset.zero),
            ),
            child: FadeTransition(opacity: enter, child: child),
          ),
        ),
      );
    },
  );
}
