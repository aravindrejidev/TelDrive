import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/neu_theme.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_surface.dart';
import 'settings_widgets.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SettingsPage(
      title: 'Appearance',
      children: [
        const NeuSectionTitle('Theme'),
        SettingsCard(
          padding: const EdgeInsets.all(14),
          children: [
            NeuSegmented<ThemeMode>(
              selected: settings.themeMode,
              onChanged: settings.setThemeMode,
              options: const [
                NeuSegment(
                  value: ThemeMode.system,
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                ),
                NeuSegment(
                  value: ThemeMode.light,
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                ),
                NeuSegment(
                  value: ThemeMode.dark,
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                ),
              ],
            ),
          ],
        ),
        const SettingsNote('System follows your phone, switching between light and dark on its own.'),
        const NeuSectionTitle('Accent colour'),
        SettingsCard(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          children: [
            _AccentPicker(
              selected: settings.accentPalette,
              onChanged: settings.setAccentPalette,
            ),
            const SizedBox(height: 14),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  settings.accentPalette.label,
                  key: ValueKey(settings.accentPalette),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.neu.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SettingsNote('Used for buttons, highlights and progress bars across the app.'),
        const NeuSectionTitle('Feedback'),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: Icons.vibration_rounded,
              title: 'Haptic feedback',
              subtitle: 'A light tap when you press buttons and switches.',
              value: settings.hapticsEnabled,
              onChanged: settings.setHapticsEnabled,
            ),
          ],
        ),
      ],
    );
  }
}

/// A row of colour swatches. The chosen one sinks into the page and shows a
/// tick; the others stand proud of it.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onChanged});

  final AccentPalette selected;
  final ValueChanged<AccentPalette> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = context.neu.isDark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final palette in AccentPalette.values)
          _Swatch(
            palette: palette,
            dark: dark,
            selected: palette == selected,
            onTap: () => onChanged(palette),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final AccentPalette palette;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.accent(dark: dark), palette.deep(dark: dark)],
    );
    return NeuTap(
      onTap: onTap,
      semanticLabel: '${palette.label} accent',
      builder: (context, pressed) => NeuSurface(
        depth: selected ? NeuDepth.inset : NeuDepth.raised,
        radius: 99,
        width: 50,
        height: 50,
        distance: selected ? 3 : 5,
        blur: selected ? 7 : 11,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            width: selected ? 32 : 26,
            height: selected ? 32 : 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: palette.accent(dark: dark).withValues(alpha: selected ? 0.45 : 0.25),
                  blurRadius: selected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.check_rounded, size: 18, color: c.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}
