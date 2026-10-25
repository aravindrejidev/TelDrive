import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/telegram_service.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/neu/neu_controls.dart';
import 'settings_widgets.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  bool _testing = false;
  String? _message;
  bool _messageIsError = false;

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'Not set';
    final colonIndex = token.indexOf(':');
    if (colonIndex == -1 || colonIndex + 5 > token.length) return '••••••••';
    return '${token.substring(0, colonIndex)}:${token.substring(colonIndex + 1, colonIndex + 5)}••••';
  }

  Future<void> _test(SettingsProvider settings) async {
    final token = settings.botToken;
    final channel = settings.channelId;
    if (token == null || channel == null) return;
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      await TelegramService(botToken: token, channelId: channel).testConnection();
      if (!mounted) return;
      setState(() {
        _message = 'Connected. The bot can post to $channel.';
        _messageIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = friendlyError(e);
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _edit(SettingsProvider settings) async {
    final saved = await showNeuDialog<bool>(
      context,
      builder: (_) => _EditConnectionDialog(settings: settings),
    );
    if (saved == true && mounted) {
      setState(() {
        _message = 'Connection updated.';
        _messageIsError = false;
      });
    }
  }

  Future<void> _signOut(SettingsProvider settings) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disconnect this bot?',
      message: 'You will need to enter the Bot Token and Channel ID again to use '
          '${AppConstants.appName}. Files already in Telegram are not touched.',
      confirmLabel: 'Disconnect',
      destructive: true,
      icon: Icons.link_off_rounded,
    );
    if (confirmed != true || !mounted) return;
    // The app gate swaps Home for the setup screen once the state changes, so
    // all that is left to do here is close the settings screens.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await settings.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return SettingsPage(
      title: 'Telegram connection',
      children: [
        const NeuSectionTitle('Your bot and channel'),
        SettingsCard(
          children: [
            NeuListRow(
              icon: Icons.key_rounded,
              title: 'Bot token',
              subtitle: _maskToken(settings.botToken),
            ),
            NeuListRow(
              icon: Icons.campaign_rounded,
              title: 'Main channel',
              subtitle: settings.channelId ?? 'Not set',
            ),
          ],
        ),
        const SettingsNote(
          'Uploads from the Photos, Videos, Audio and Documents tabs go to the '
          'main channel. Sync links can send to other channels with the same bot.',
        ),
        SettingsButton(
          label: _testing ? 'Testing…' : 'Test connection',
          icon: Icons.network_check_rounded,
          loading: _testing,
          topGap: 20,
          onPressed: _testing ? null : () => _test(settings),
        ),
        SettingsButton(
          label: 'Change token or channel',
          icon: Icons.edit_rounded,
          topGap: 14,
          onPressed: () => _edit(settings),
        ),
        if (_message != null) SettingsMessage(text: _message!, isError: _messageIsError),
        const NeuSectionTitle('Danger zone'),
        const SettingsNote(
          'Disconnecting removes the saved token and channel from this phone. '
          'Your files and your sync links are kept.',
        ),
        SettingsButton(
          label: 'Disconnect bot',
          icon: Icons.link_off_rounded,
          style: NeuButtonStyle.danger,
          onPressed: () => _signOut(settings),
        ),
      ],
    );
  }
}

class _EditConnectionDialog extends StatefulWidget {
  const _EditConnectionDialog({required this.settings});

  final SettingsProvider settings;

  @override
  State<_EditConnectionDialog> createState() => _EditConnectionDialogState();
}

class _EditConnectionDialogState extends State<_EditConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _tokenController = TextEditingController(text: widget.settings.botToken ?? '');
  late final _channelController = TextEditingController(text: widget.settings.channelId ?? '');
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.settings.saveCredentials(
        newBotToken: _tokenController.text,
        newChannelId: _channelController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuDialogCard(
      title: 'Change connection',
      icon: Icons.edit_rounded,
      actions: [
        NeuButton(
          label: 'Cancel',
          height: 50,
          style: NeuButtonStyle.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
        NeuButton(
          label: _saving ? 'Checking…' : 'Save',
          height: 50,
          loading: _saving,
          onPressed: _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeuTextField(
              controller: _tokenController,
              label: 'Bot token',
              icon: Icons.key_rounded,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              trailing: NeuIconButton(
                icon: _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 36,
                iconSize: 18,
                tooltip: _obscure ? 'Show token' : 'Hide token',
                onTap: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                final token = v?.trim() ?? '';
                if (token.isEmpty) return 'Enter the token from @BotFather';
                if (!token.contains(':')) return 'That does not look like a bot token';
                return null;
              },
            ),
            const SizedBox(height: 16),
            NeuTextField(
              controller: _channelController,
              label: 'Main channel',
              icon: Icons.campaign_rounded,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a channel username or ID' : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
              child: Text(
                'Files are tied to the bot that uploaded them. After switching to a '
                'different bot, older files can still be opened in Telegram but may '
                'not download in the app.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textMuted),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: c.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
