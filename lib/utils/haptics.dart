import 'package:flutter/services.dart';

/// One switch for every tap, toggle and selection buzz in the app, so the
/// "Haptic feedback" setting can turn them all off at once.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
