import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../home/home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
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
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_upload_rounded, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Connect your Telegram Bot', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  '${AppConstants.appName} stores your files by uploading them to a '
                  'private Telegram channel through a bot you control. Nothing is '
                  'sent to any other server.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    labelText: 'Bot Token',
                    hintText: '123456789:AAExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureToken
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureToken = !_obscureToken),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Bot Token is required';
                    if (!value.contains(':')) return 'That doesn\'t look like a valid Bot Token';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConstants.botFatherUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("Get a token from @BotFather"),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _channelController,
                  decoration: const InputDecoration(
                    labelText: 'Channel ID',
                    hintText: '@my_private_backup  or  -1001234567890',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Channel ID is required';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'This is your primary channel — used for manual uploads from the '
                  'Photos/Videos/Audio/Documents tabs. You can add more channels '
                  'later in Settings for automatic folder syncing.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Test Connection & Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
