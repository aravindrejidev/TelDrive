import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_surface.dart';

/// First-run screen. When the credentials are saved, [SettingsProvider]
/// flips to `ready` and the app gate swaps this screen for Home on its own,
/// so there is no navigation to do here.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Optional: values baked in at build time with --dart-define. Anything put
  // here ends up readable inside the APK, so only use it for private builds.
  static const _defaultBotToken = String.fromEnvironment('DEFAULT_BOT_TOKEN');
  static const _defaultChannelId = String.fromEnvironment('DEFAULT_CHANNEL_ID');

  final _formKey = GlobalKey<FormState>();
  late final _tokenController = TextEditingController(text: _defaultBotToken);
  late final _channelController = TextEditingController(text: _defaultChannelId);
  bool _obscureToken = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<SettingsProvider>().saveCredentials(
            newBotToken: _tokenController.text,
            newChannelId: _channelController.text,
          );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 92, glow: true),
                const SizedBox(height: 28),
                Text('Connect your\nTelegram bot', style: textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  '${AppConstants.appName} keeps your files in a private Telegram '
                  'channel, through a bot you control. Nothing is sent to any '
                  'other server.',
                  style: TextStyle(fontSize: 15, height: 1.5, color: c.textMuted),
                ),
                const SizedBox(height: 26),
                const _StepsCard(),
                const SizedBox(height: 28),
                NeuTextField(
                  controller: _tokenController,
                  label: 'Bot token',
                  hint: '123456789:AAE…',
                  icon: Icons.key_rounded,
                  obscureText: _obscureToken,
                  textInputAction: TextInputAction.next,
                  trailing: NeuIconButton(
                    icon: _obscureToken
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 36,
                    iconSize: 18,
                    tooltip: _obscureToken ? 'Show token' : 'Hide token',
                    onTap: () => setState(() => _obscureToken = !_obscureToken),
                  ),
                  validator: (value) {
                    final token = value?.trim() ?? '';
                    if (token.isEmpty) return 'Enter the token from @BotFather';
                    if (!token.contains(':')) return 'That does not look like a bot token';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => launchUrl(
                      Uri.parse(AppConstants.botFatherUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 16, color: c.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Open @BotFather',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NeuTextField(
                  controller: _channelController,
                  label: 'Channel',
                  hint: '@my_private_backup or -1001234567890',
                  icon: Icons.campaign_rounded,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your channel username or ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'This is your main channel, used for uploads from the tabs. '
                    'You can add more channels later in Settings for folder syncing.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: c.textMuted),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 18),
                  NeuSurface(
                    depth: NeuDepth.inset,
                    radius: 20,
                    distance: 4,
                    blur: 9,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: c.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: c.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                NeuButton(
                  label: _isSaving ? 'Checking…' : 'Connect',
                  icon: _isSaving ? null : Icons.link_rounded,
                  loading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  static const _steps = [
    'Create a bot with @BotFather and copy its token.',
    'Create a private channel and add the bot as an admin who can post.',
    'Paste the token and the channel below.',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 26,
      distance: 5,
      blur: 12,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeuSurface(
                    radius: 99,
                    width: 28,
                    height: 28,
                    distance: 2.5,
                    blur: 6,
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _steps[i],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
