import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/neu_theme.dart';
import 'neu_surface.dart';

// ---------------------------------------------------------------------------
// Press handling
// ---------------------------------------------------------------------------

/// Gives anything the "pushed into the page" feel: it reports whether the
/// finger is down so the child can switch from raised to inset, and nudges the
/// scale slightly.
class NeuTap extends StatefulWidget {
  const NeuTap({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.haptics = true,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final bool haptics;

  @override
  State<NeuTap> createState() => _NeuTapState();
}

class _NeuTapState extends State<NeuTap> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptics) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 46,
    this.iconSize = 22,
    this.color,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;

  /// Shows the button pressed in, for toggles that are currently on.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final button = NeuTap(
      onTap: onTap,
      semanticLabel: tooltip,
      builder: (context, pressed) => NeuSurface(
        depth: (pressed || active) ? NeuDepth.inset : NeuDepth.raised,
        radius: size,
        width: size,
        height: size,
        distance: 4,
        blur: 10,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? (active ? c.accent : c.text),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

enum NeuButtonStyle { primary, secondary, danger }

class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = NeuButtonStyle.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NeuButtonStyle style;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final enabled = onPressed != null && !loading;
    final foreground = switch (style) {
      NeuButtonStyle.primary => c.onAccent,
      NeuButtonStyle.secondary => c.text,
      NeuButtonStyle.danger => c.danger,
    };

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: NeuTap(
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
        builder: (context, pressed) {
          final content = Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: foreground),
              if (loading || icon != null) const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          );

          if (style == NeuButtonStyle.primary) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: height,
              padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 26),
              decoration: BoxDecoration(
                gradient: c.accentGradient,
                borderRadius: BorderRadius.circular(height),
                boxShadow: pressed
                    ? [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: c.shadowDark,
                          blurRadius: 16,
                          offset: const Offset(6, 6),
                        ),
                        BoxShadow(
                          color: c.shadowLight,
                          blurRadius: 16,
                          offset: const Offset(-5, -5),
                        ),
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.34),
                          blurRadius: 20,
                          offset: const Offset(0, 9),
                        ),
                      ],
              ),
              child: content,
            );
          }

          return NeuSurface(
            depth: pressed ? NeuDepth.inset : NeuDepth.raised,
            radius: height,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 26),
            distance: 5,
            blur: 13,
            child: Center(child: content),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

/// An icon filled with the accent gradient.
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, this.size = 24});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradient = context.neu.accentGradient;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// A small pressed-in label, used for status such as "On this device".
class NeuChip extends StatelessWidget {
  const NeuChip({super.key, required this.label, this.icon, this.iconColor});

  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 99,
      distance: 2,
      blur: 5,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? c.accent),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A groove with an accent-gradient fill.
class NeuProgressBar extends StatelessWidget {
  const NeuProgressBar({super.key, required this.value, this.height = 12});

  /// 0 to 1.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(clamped * 100).round()}%',
      child: NeuSurface(
        depth: NeuDepth.inset,
        radius: 99,
        width: double.infinity,
        height: height,
        distance: 2.5,
        blur: 5,
        padding: const EdgeInsets.all(2.5),
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: constraints.maxWidth * clamped,
              height: constraints.maxHeight,
              decoration: BoxDecoration(
                gradient: c.accentGradient,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeuSwitch extends StatelessWidget {
  const NeuSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final handler = onChanged;
    return Semantics(
      toggled: value,
      enabled: handler != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handler == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                handler(!value);
              },
        child: NeuSurface(
          depth: NeuDepth.inset,
          radius: 99,
          width: 60,
          height: 34,
          distance: 3,
          blur: 7,
          padding: const EdgeInsets.all(5),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: value ? c.accentGradient : c.surfaceGradient,
                boxShadow: [
                  BoxShadow(
                    color: c.shadowDark,
                    blurRadius: 6,
                    offset: const Offset(2, 2),
                  ),
                  BoxShadow(
                    color: c.shadowLight,
                    blurRadius: 6,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabs and segmented choice
// ---------------------------------------------------------------------------

class _PillOption extends StatelessWidget {
  const _PillOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.vertical,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final iconWidget = icon == null
        ? null
        : Icon(icon, size: 20, color: selected ? c.accent : c.textMuted);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: vertical ? 11.5 : 13.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? c.text : c.textMuted,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: vertical ? 10 : 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected ? c.surfaceGradient : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.shadowDark,
                      blurRadius: 10,
                      offset: const Offset(4, 4),
                    ),
                    BoxShadow(
                      color: c.shadowLight,
                      blurRadius: 10,
                      offset: const Offset(-3, -3),
                    ),
                  ]
                : const [],
          ),
          child: vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconWidget != null) iconWidget,
                    const SizedBox(height: 3),
                    text,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconWidget != null) ...[iconWidget, const SizedBox(width: 6)],
                    Flexible(child: text),
                  ],
                ),
        ),
      ),
    );
  }
}

class NeuTabItem {
  const NeuTabItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Tab strip that follows a [TabController], including while swiping.
class NeuTabs extends StatelessWidget {
  const NeuTabs({super.key, required this.controller, required this.items});

  final TabController controller;
  final List<NeuTabItem> items;

  @override
  Widget build(BuildContext context) {
    final animation = controller.animation!;
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 26,
      distance: 4,
      blur: 9,
      padding: const EdgeInsets.all(5),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final selected = animation.value.round().clamp(0, items.length - 1);
          return Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _PillOption(
                    label: items[i].label,
                    icon: items[i].icon,
                    selected: i == selected,
                    vertical: true,
                    onTap: () => controller.animateTo(i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class NeuSegment<T> {
  const NeuSegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class NeuSegmented<T> extends StatelessWidget {
  const NeuSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<NeuSegment<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 22,
      distance: 3,
      blur: 8,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: _PillOption(
                label: option.label,
                icon: option.icon,
                selected: option.value == selected,
                vertical: false,
                onTap: () => onChanged(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text input
// ---------------------------------------------------------------------------

/// A form field styled as a groove cut into the page. Works inside a [Form]
/// and shows its validation message underneath the groove.
class NeuTextField extends FormField<String> {
  NeuTextField({
    super.key,
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscureText = false,
    Widget? trailing,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
  }) : super(
          initialValue: controller.text,
          validator: validator,
          builder: (state) {
            final c = state.context.neu;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                ),
                NeuSurface(
                  depth: NeuDepth.inset,
                  radius: 20,
                  distance: 4,
                  blur: 9,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: c.textMuted),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: TextField(
                          controller: controller,
                          obscureText: obscureText,
                          keyboardType: keyboardType,
                          textInputAction: textInputAction,
                          autocorrect: false,
                          enableSuggestions: false,
                          cursorColor: c.accent,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            hintStyle: TextStyle(
                              color: c.textMuted.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                          onChanged: (value) {
                            state.didChange(value);
                            onChanged?.call(value);
                          },
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 8),
                    child: Text(
                      state.errorText ?? '',
                      style: TextStyle(
                        color: c.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

/// Top bar for sub-screens: a raised back button and a title.
class NeuPageHeader extends StatelessWidget {
  const NeuPageHeader({super.key, required this.title, this.onBack, this.actions = const []});

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            NeuIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 18,
              tooltip: 'Back',
              onTap: onBack,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class NeuSectionTitle extends StatelessWidget {
  const NeuSectionTitle(this.title, {super.key, this.padding});

  final String title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(26, 28, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: context.neu.text,
        ),
      ),
    );
  }
}

/// A row with an icon in a small groove, a title, optional detail text and an
/// optional trailing widget. Used throughout Settings.
class NeuListRow extends StatelessWidget {
  const NeuListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Colours the icon and title, for example red for a destructive choice.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          NeuSurface(
            depth: NeuDepth.inset,
            radius: 99,
            width: 44,
            height: 44,
            distance: 3,
            blur: 7,
            child: Center(child: Icon(icon, size: 20, color: tone ?? c.accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tone ?? c.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

// ---------------------------------------------------------------------------
// Dialogs and sheets
// ---------------------------------------------------------------------------

/// A dialog route with a soft fade and scale, lifted above the keyboard.
Future<T?> showNeuDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) => SafeArea(
      child: Builder(
        builder: (innerContext) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(innerContext).bottom),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                type: MaterialType.transparency,
                child: builder(dialogContext),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class NeuDialogCard extends StatelessWidget {
  const NeuDialogCard({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.child,
    this.actions = const [],
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: NeuSurface(
        radius: 30,
        distance: 10,
        blur: 24,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    NeuSurface(
                      depth: NeuDepth.inset,
                      radius: 99,
                      width: 46,
                      height: 46,
                      distance: 3,
                      blur: 7,
                      child: Center(
                        child: Icon(icon, size: 22, color: iconColor ?? c.accent),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
              if (child != null) ...[const SizedBox(height: 16), child!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet in the same material as the page.
Future<T?> showNeuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: NeuSurface(
        radius: 32,
        distance: 10,
        blur: 24,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: NeuSurface(
                    depth: NeuDepth.inset,
                    radius: 99,
                    width: 44,
                    height: 6,
                    distance: 1.5,
                    blur: 3,
                  ),
                ),
                const SizedBox(height: 18),
                builder(sheetContext),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
