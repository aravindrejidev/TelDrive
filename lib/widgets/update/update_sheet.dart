import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/update_info.dart';
import '../../providers/update_provider.dart';
import '../../theme/neu_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/haptics.dart';
import '../neu/neu_controls.dart';
import '../neu/neu_surface.dart';
import 'release_notes_view.dart';
import 'update_hero.dart';

/// Opens the update sheet: the screen blurs and dims, and the card springs up
/// from the bottom. The same sheet is used for the automatic prompt at start
/// up and for "View update" in Settings.
Future<void> showUpdateSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (context, _, __) => const _UpdateSheet(),
    transitionBuilder: (context, animation, _, child) {
      final reversing = animation.status == AnimationStatus.reverse;
      final fade = Curves.easeOut.transform(animation.value).clamp(0.0, 1.0);
      // Spring up on the way in, glide away on the way out.
      final lift = reversing
          ? Curves.easeInCubic.transform(animation.value)
          : Curves.easeOutBack.transform(animation.value);

      Widget backdrop = ColoredBox(color: Colors.black.withValues(alpha: 0.42 * fade));
      final sigma = 9.0 * fade;
      if (sigma > 0.1) {
        backdrop = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: backdrop,
        );
      }

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: backdrop,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionalTranslation(
              translation: Offset(0, 0.22 * (1 - lift)),
              child: Opacity(opacity: fade, child: child),
            ),
          ),
        ],
      );
    },
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet();

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _enter;
  late final AnimationController _shake;
  late final UpdateProvider _updates;
  UpdatePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    _updates = context.read<UpdateProvider>();
    _lastPhase = _updates.phase;
    _updates.addListener(_onUpdateChanged);
  }

  void _onUpdateChanged() {
    final phase = _updates.phase;
    if (phase != _lastPhase) {
      if (phase == UpdatePhase.error) {
        Haptics.heavy();
        _shake.forward(from: 0);
      } else if (phase == UpdatePhase.ready) {
        Haptics.medium();
      }
    }
    _lastPhase = phase;
  }

  @override
  void dispose() {
    _updates.removeListener(_onUpdateChanged);
    _pulse.dispose();
    _enter.dispose();
    _shake.dispose();
    super.dispose();
  }

  /// Fades and lifts [child] in during its slice of the opening animation.
  Widget _stagger(double begin, double end, Widget child) {
    final slice = _enter.drive(
      CurveTween(curve: Interval(begin, end, curve: Curves.easeOutCubic)),
    );
    return FadeTransition(
      opacity: slice,
      child: SlideTransition(
        position: slice.drive(
          Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Consumer<UpdateProvider>(
        builder: (context, u, _) {
          final info = u.info;
          if (info == null) return const SizedBox.shrink();
          return AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 7) * 10 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _buildCard(context, u, info),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, UpdateProvider u, UpdateInfo info) {
    final media = MediaQuery.of(context);
    final showNotes = u.phase == UpdatePhase.available;
    final showProgress =
        u.phase == UpdatePhase.downloading || u.phase == UpdatePhase.verifying;
    const open = SizedBox(width: double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GestureDetector(
        // Keeps taps on the card from reaching the dismiss area behind it.
        onTap: () {},
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: media.size.height * 0.92,
          ),
          child: NeuSurface(
            radius: 38,
            distance: 11,
            blur: 28,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _stagger(
                        0,
                        0.3,
                        const NeuSurface(
                          depth: NeuDepth.inset,
                          radius: 99,
                          width: 44,
                          height: 6,
                          distance: 1.5,
                          blur: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stagger(
                      0.05,
                      0.5,
                      Center(
                        child: UpdateHero(
                          phase: u.phase,
                          progress: u.progress,
                          pulse: _pulse,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _stagger(0.15, 0.6, _TitleBlock(u: u, info: info)),
                    const SizedBox(height: 16),
                    _stagger(
                      0.25,
                      0.7,
                      _VersionRow(
                        current: u.currentVersion,
                        next: info.version,
                        bytes: info.apkBytes,
                        pulse: _pulse,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: showNotes
                          ? Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: _stagger(0.4, 0.9, _NotesPanel(notes: info.notes)),
                            )
                          : open,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: showProgress
                          ? Padding(
                              padding: const EdgeInsets.only(top: 22),
                              child: _ProgressPanel(u: u),
                            )
                          : open,
                    ),
                    const SizedBox(height: 22),
                    _stagger(
                      0.55,
                      1,
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: _swap,
                          child: KeyedSubtree(
                            key: ValueKey<UpdatePhase>(u.phase),
                            child: _buildActions(context, u),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, UpdateProvider u) {
    final navigator = Navigator.of(context);
    void close() => navigator.maybePop();

    // A narrow secondary button beside a wide primary one, so the primary
    // label and its icon always fit.
    Widget pair(Widget secondary, Widget primary) => Row(
          children: [
            Expanded(flex: 2, child: secondary),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: primary),
          ],
        );

    NeuButton later() => NeuButton(
          label: 'Later',
          height: 54,
          style: NeuButtonStyle.secondary,
          onPressed: close,
        );

    switch (u.phase) {
      case UpdatePhase.downloading:
        return pair(
          NeuButton(
            label: 'Cancel',
            height: 54,
            style: NeuButtonStyle.danger,
            onPressed: u.cancelDownload,
          ),
          NeuButton(
            label: 'Hide',
            icon: Icons.keyboard_arrow_down_rounded,
            height: 54,
            style: NeuButtonStyle.secondary,
            onPressed: close,
          ),
        );
      case UpdatePhase.verifying:
        return const NeuButton(label: 'Verifying…', loading: true, height: 54);
      case UpdatePhase.ready:
        return pair(
          later(),
          NeuButton(
            label: 'Install now',
            icon: Icons.install_mobile_rounded,
            height: 54,
            onPressed: u.install,
          ),
        );
      case UpdatePhase.needsPermission:
        return pair(
          later(),
          NeuButton(
            label: 'Allow installs',
            icon: Icons.lock_open_rounded,
            height: 54,
            onPressed: u.install,
          ),
        );
      case UpdatePhase.installing:
        return const NeuButton(label: 'Opening installer…', loading: true, height: 54);
      case UpdatePhase.error:
        return pair(
          NeuButton(
            label: 'Close',
            height: 54,
            style: NeuButtonStyle.secondary,
            onPressed: close,
          ),
          NeuButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            height: 54,
            onPressed: u.retry,
          ),
        );
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pair(
              later(),
              NeuButton(
                label: 'Update now',
                icon: Icons.download_rounded,
                height: 54,
                onPressed: u.startDownload,
              ),
            ),
            _TextAction(
              label: 'Skip this version',
              onTap: () async {
                await u.skipThisVersion();
                close();
              },
            ),
          ],
        );
    }
  }
}

Widget _swap(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(animation),
      child: child,
    ),
  );
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.u, required this.info});

  final UpdateProvider u;
  final UpdateInfo info;

  (String, String) _copy() {
    switch (u.phase) {
      case UpdatePhase.downloading:
        return ('Downloading update', 'Getting TeleDrive ${info.version}.');
      case UpdatePhase.verifying:
        return ('Verifying download', 'Making sure the file arrived intact.');
      case UpdatePhase.ready:
        return (
          'Ready to install',
          u.checksumVerified
              ? 'The download was checked and is safe to install.'
              : 'The download is complete.',
        );
      case UpdatePhase.needsPermission:
        return (
          'One more step',
          'Android needs your permission before TeleDrive can install updates. '
              'Tap Allow installs, switch the option on, then come back.',
        );
      case UpdatePhase.installing:
        return ('Opening the installer', 'Confirm on the next screen.');
      case UpdatePhase.error:
        return ('That did not work', u.errorMessage ?? 'Something went wrong.');
      default:
        return ('Update available', 'TeleDrive ${info.version} is ready for you.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final (title, subtitle) = _copy();
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: _swap,
        child: Column(
          key: ValueKey<UpdatePhase>(u.phase),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 25),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: u.phase == UpdatePhase.error ? c.danger : c.textMuted,
                fontWeight: u.phase == UpdatePhase.error ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.current,
    required this.next,
    required this.bytes,
    required this.pulse,
  });

  final AppVersion? current;
  final AppVersion next;
  final int bytes;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        if (current != null) ...[
          NeuChip(label: 'v$current'),
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) => Transform.translate(
              offset: Offset(4 * Curves.easeInOut.transform(pulse.value), 0),
              child: child,
            ),
            child: Icon(Icons.arrow_forward_rounded, size: 20, color: c.accent),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: c.accentGradient,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            'v$next',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: c.onAccent,
            ),
          ),
        ),
        if (bytes > 0)
          NeuChip(
            icon: Icons.download_rounded,
            label: Formatters.fileSize(bytes),
          ),
      ],
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 26,
      distance: 5,
      blur: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: ReleaseNotesView(notes: notes),
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.u});

  final UpdateProvider u;

  static String _eta(Duration d) {
    final seconds = d.inSeconds;
    if (seconds < 60) return '${seconds}s left';
    return '${seconds ~/ 60}m ${seconds % 60}s left';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final verifying = u.phase == UpdatePhase.verifying;
    final eta = u.eta;
    final speed = u.bytesPerSecond > 0
        ? '${Formatters.fileSize(u.bytesPerSecond.round())}/s'
            '${eta == null ? '' : ', ${_eta(eta)}'}'
        : 'Starting…';

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: u.progress * 100),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, _) => Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 10),
        NeuProgressBar(value: u.progress, height: 14),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                verifying
                    ? 'Checking the file…'
                    : '${Formatters.fileSize(u.receivedBytes)} of ${Formatters.fileSize(u.totalBytes)}',
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ),
            if (!verifying)
              Text(
                speed,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.neu.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
