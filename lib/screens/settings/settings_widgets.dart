import 'package:flutter/material.dart';
import '../../theme/neu_theme.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_reveal.dart';
import '../../widgets/neu/neu_surface.dart';

/// The frame every settings screen shares: a header with a back button and a
/// scrolling list whose rows ease in one after another.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NeuPageHeader(title: title, onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  0,
                  4,
                  0,
                  MediaQuery.paddingOf(context).bottom + 36,
                ),
                children: [
                  for (var i = 0; i < children.length; i++)
                    NeuReveal(index: i, child: children[i]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A raised panel that groups related rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuSurface(
        radius: 28,
        distance: 7,
        blur: 16,
        padding: padding ?? const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Small explanatory text under a section.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 13.5, height: 1.45, color: context.neu.textMuted),
      ),
    );
  }
}

/// A row with an on/off switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return NeuListRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: NeuSwitch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

/// A row that picks one option out of several, with a tick on the chosen one.
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuListRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: selected
            ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: c.accent)
            : Icon(
                Icons.circle_outlined,
                key: const ValueKey('off'),
                color: c.textMuted.withValues(alpha: 0.5),
              ),
      ),
    );
  }
}

/// A pressed-in panel for the result of an action, in green or red.
class SettingsMessage extends StatelessWidget {
  const SettingsMessage({super.key, required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: NeuSurface(
        depth: NeuDepth.inset,
        radius: 22,
        distance: 4,
        blur: 10,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 20,
              color: isError ? c.danger : c.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: isError ? c.danger : c.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-width button with the page's side margins.
class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = NeuButtonStyle.secondary,
    this.loading = false,
    this.topGap = 16,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NeuButtonStyle style;
  final bool loading;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topGap, 20, 0),
      child: NeuButton(
        label: label,
        icon: icon,
        height: 52,
        style: style,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}

/// A tappable card that opens another screen: used for the Settings home and
/// the rows of the About screen.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.badge = false,
  }) : assert(icon != null || leading != null);

  final IconData? icon;

  /// Replaces the icon, for example with a profile picture.
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Shows a small accent dot, to point out something that needs attention.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: NeuTap(
        onTap: onTap,
        semanticLabel: title,
        builder: (context, pressed) => NeuSurface(
          depth: pressed ? NeuDepth.inset : NeuDepth.raised,
          radius: 26,
          distance: 6,
          blur: 14,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NeuSurface(
                    depth: NeuDepth.inset,
                    radius: 99,
                    width: 52,
                    height: 52,
                    distance: 3.5,
                    blur: 8,
                    child: Center(
                      child: leading ?? Icon(icon, size: 23, color: c.accent),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    top: -1,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        scale: badge ? 1 : 0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: c.accentGradient,
                            border: Border.all(color: c.baseHigh, width: 2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: c.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, height: 1.3, color: c.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
