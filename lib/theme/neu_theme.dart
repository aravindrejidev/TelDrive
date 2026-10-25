import 'package:flutter/material.dart';

/// The colour system behind the soft, extruded look.
///
/// Neumorphism only works when every raised or pressed element is the same
/// material as the page behind it, lit from the top-left. So there is one
/// [base] surface, a slightly lighter and darker tint of it ([baseHigh] and
/// [baseLow]) for gradients, and a pair of shadows: [shadowLight] for the lit
/// edge and [shadowDark] for the shaded one. A single [accent] gradient is
/// the only saturated colour in the app, reserved for the thing to press next.
@immutable
class NeuColors extends ThemeExtension<NeuColors> {
  const NeuColors({
    required this.isDark,
    required this.base,
    required this.baseHigh,
    required this.baseLow,
    required this.shadowLight,
    required this.shadowDark,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.success,
    required this.danger,
  });

  final bool isDark;
  final Color base;
  final Color baseHigh;
  final Color baseLow;
  final Color shadowLight;
  final Color shadowDark;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color accentDeep;
  final Color onAccent;
  final Color success;
  final Color danger;

  static const NeuColors light = NeuColors(
    isDark: false,
    base: Color(0xFFE4E9F2),
    baseHigh: Color(0xFFEDF1F8),
    baseLow: Color(0xFFD9DFEA),
    shadowLight: Color(0xFFFFFFFF),
    shadowDark: Color(0xFFB4BED2),
    text: Color(0xFF273044),
    textMuted: Color(0xFF5B657A),
    accent: Color(0xFF4F6EF7),
    accentDeep: Color(0xFF6A4CF0),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF1F9D6B),
    danger: Color(0xFFD13A57),
  );

  static const NeuColors dark = NeuColors(
    isDark: true,
    base: Color(0xFF262A33),
    baseHigh: Color(0xFF2D323C),
    baseLow: Color(0xFF21242C),
    shadowLight: Color(0xFF323844),
    shadowDark: Color(0xFF15171C),
    text: Color(0xFFE9EDF5),
    textMuted: Color(0xFF9CA6BB),
    accent: Color(0xFF8CA0FF),
    accentDeep: Color(0xFF9B7DFF),
    onAccent: Color(0xFF10131F),
    success: Color(0xFF45C795),
    danger: Color(0xFFFF7A90),
  );

  /// The same palette with a different accent gradient.
  NeuColors withAccent(Color newAccent, Color newAccentDeep) => NeuColors(
        isDark: isDark,
        base: base,
        baseHigh: baseHigh,
        baseLow: baseLow,
        shadowLight: shadowLight,
        shadowDark: shadowDark,
        text: text,
        textMuted: textMuted,
        accent: newAccent,
        accentDeep: newAccentDeep,
        onAccent: onAccent,
        success: success,
        danger: danger,
      );

  /// Raised surfaces: lit from the top-left, so lighter there.
  LinearGradient get surfaceGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [baseHigh, baseLow],
      );

  /// Pressed-in surfaces catch the light the other way round.
  LinearGradient get insetGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [baseLow, baseHigh],
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentDeep],
      );

  /// The standard two-sided shadow of a raised element.
  List<BoxShadow> raisedShadows({double distance = 7, double blur = 16}) => [
        BoxShadow(
          color: shadowDark,
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: shadowLight,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
      ];

  @override
  NeuColors copyWith() => this;

  @override
  NeuColors lerp(ThemeExtension<NeuColors>? other, double t) {
    if (other is! NeuColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return NeuColors(
      isDark: t < 0.5 ? isDark : other.isDark,
      base: mix(base, other.base),
      baseHigh: mix(baseHigh, other.baseHigh),
      baseLow: mix(baseLow, other.baseLow),
      shadowLight: mix(shadowLight, other.shadowLight),
      shadowDark: mix(shadowDark, other.shadowDark),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      accentDeep: mix(accentDeep, other.accentDeep),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
    );
  }
}

/// The accent gradient people can pick in Settings. Each one has a stronger
/// version for the light theme and a lighter one for the dark theme, so text
/// on it stays readable in both.
enum AccentPalette { indigo, ocean, emerald, sunset, violet }

extension AccentPaletteX on AccentPalette {
  String get label => switch (this) {
        AccentPalette.indigo => 'Indigo',
        AccentPalette.ocean => 'Ocean',
        AccentPalette.emerald => 'Emerald',
        AccentPalette.sunset => 'Sunset',
        AccentPalette.violet => 'Violet',
      };

  Color accent({required bool dark}) => switch (this) {
        AccentPalette.indigo => dark ? const Color(0xFF8CA0FF) : const Color(0xFF4F6EF7),
        AccentPalette.ocean => dark ? const Color(0xFF5CB8FF) : const Color(0xFF0F7FD4),
        AccentPalette.emerald => dark ? const Color(0xFF4FD1A0) : const Color(0xFF138F62),
        AccentPalette.sunset => dark ? const Color(0xFFFF8FA3) : const Color(0xFFDB4468),
        AccentPalette.violet => dark ? const Color(0xFFB39DFF) : const Color(0xFF7B5CF0),
      };

  Color deep({required bool dark}) => switch (this) {
        AccentPalette.indigo => dark ? const Color(0xFF9B7DFF) : const Color(0xFF6A4CF0),
        AccentPalette.ocean => dark ? const Color(0xFF4FD6C4) : const Color(0xFF11A29C),
        AccentPalette.emerald => dark ? const Color(0xFF3CC5C5) : const Color(0xFF0E7C86),
        AccentPalette.sunset => dark ? const Color(0xFFFFB26B) : const Color(0xFFDE6238),
        AccentPalette.violet => dark ? const Color(0xFFD29BFF) : const Color(0xFFA24FEF),
      };
}

extension NeuContext on BuildContext {
  NeuColors get neu => Theme.of(this).extension<NeuColors>()!;
}

ThemeData buildNeuTheme(
  Brightness brightness, {
  AccentPalette palette = AccentPalette.indigo,
}) {
  final isDark = brightness == Brightness.dark;
  final c = (isDark ? NeuColors.dark : NeuColors.light).withAccent(
    palette.accent(dark: isDark),
    palette.deep(dark: isDark),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
  ).copyWith(
    surface: c.base,
    onSurface: c.text,
    onSurfaceVariant: c.textMuted,
    primary: c.accent,
    onPrimary: c.onAccent,
    error: c.danger,
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true)
      .textTheme
      .apply(bodyColor: c.text, displayColor: c.text);

  final textTheme = base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.base,
    canvasColor: c.base,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.isDark ? c.baseHigh : c.text,
      contentTextStyle: TextStyle(
        color: c.isDark ? c.text : c.base,
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    extensions: <ThemeExtension<dynamic>>[c],
  );
}
