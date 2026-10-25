import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/update_provider.dart';
import '../../theme/neu_theme.dart';
import '../../utils/app_info.dart';
import '../../utils/constants.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_route.dart';
import '../../widgets/neu/neu_surface.dart';
import 'settings_widgets.dart';
import 'updates_settings_screen.dart';

/// The About page: who made the app, where the code lives, and which version
/// is installed.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, Uri? uri) async {
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  void _showMeet(BuildContext context) {
    showNeuSheet<void>(
      context,
      builder: (sheetContext) {
        final c = sheetContext.neu;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Meet ${AppConstants.appName}',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'A drive that lives in your own Telegram, with nothing in between.',
              style: TextStyle(fontSize: 14.5, height: 1.45, color: c.textMuted),
            ),
            const SizedBox(height: 12),
            const NeuListRow(
              icon: Icons.lock_rounded,
              title: 'Your own cloud',
              subtitle: 'Files go to a private Telegram channel that only you control.',
            ),
            const NeuListRow(
              icon: Icons.sync_rounded,
              title: 'Sync that just works',
              subtitle: 'Link a folder to a channel and new files upload on their own.',
            ),
            const NeuListRow(
              icon: Icons.cloud_download_rounded,
              title: 'Get it back any time',
              subtitle: 'Download a file again, or open it straight in Telegram.',
            ),
            const NeuListRow(
              icon: Icons.rocket_launch_rounded,
              title: 'Always improving',
              subtitle: 'The app updates itself from its GitHub releases.',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final updates = context.watch<UpdateProvider>();
    final version = updates.currentVersion;
    final build = updates.currentBuild;
    final owner = AppInfo.owner;

    return SettingsPage(
      title: 'About',
      children: [
        _HeroCard(version: version?.toString()),
        const SizedBox(height: 14),
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Meet ${AppConstants.appName}',
          subtitle: 'What it does and how it works',
          onTap: () => _showMeet(context),
        ),
        if (AppInfo.hasRepository) ...[
          const NeuSectionTitle('Contributors'),
          SettingsTile(
            leading: _Avatar(url: AppInfo.ownerAvatarUrl, fallback: owner ?? '?'),
            title: owner ?? '',
            subtitle: 'Developer',
            onTap: () => _open(context, AppInfo.ownerUri),
          ),
          const NeuSectionTitle('Links'),
          SettingsTile(
            icon: Icons.code_rounded,
            title: 'Source code',
            subtitle: 'github.com/${AppInfo.repository}',
            onTap: () => _open(context, AppInfo.repositoryUri),
          ),
          SettingsTile(
            icon: Icons.bug_report_rounded,
            title: 'Report a problem',
            subtitle: 'Open an issue on GitHub',
            onTap: () => _open(context, AppInfo.issuesUri),
          ),
          SettingsTile(
            icon: Icons.new_releases_rounded,
            title: 'Release history',
            subtitle: 'See what changed in every version',
            onTap: () => _open(context, AppInfo.releasesUri),
          ),
        ],
        const NeuSectionTitle('App'),
        SettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'Version',
          subtitle: version == null
              ? 'Reading version…'
              : build.isEmpty
                  ? 'v$version'
                  : 'v$version (build $build)',
          showChevron: false,
        ),
        SettingsTile(
          icon: Icons.system_update_rounded,
          title: 'Updates',
          subtitle: updates.hasPendingUpdate
              ? 'Version ${updates.info?.version} is available'
              : 'Check for a newer version',
          badge: updates.hasPendingUpdate,
          onTap: () => Navigator.of(context).push(neuRoute(const UpdatesSettingsScreen())),
        ),
        SettingsTile(
          icon: Icons.description_rounded,
          title: 'Open source licences',
          subtitle: 'The libraries ${AppConstants.appName} is built with',
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConstants.appName,
            applicationVersion: version?.toString(),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            [
              '© ${DateTime.now().year}${owner == null ? '' : ' $owner'}',
              if (AppInfo.commit.isNotEmpty) AppInfo.shortCommit,
            ].join(' · '),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuSurface(
        radius: 34,
        distance: 9,
        blur: 22,
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
        child: Column(
          children: [
            const BrandLogo(size: 112, glow: true),
            const SizedBox(height: 22),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (version != null) ...[
              const SizedBox(height: 12),
              NeuSurface(
                depth: NeuDepth.inset,
                radius: 99,
                distance: 2.5,
                blur: 6,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  'v$version',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Keep your files in your own private Telegram channel, sync '
              'folders automatically, and get them back whenever you need.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round profile picture with the first letter as a fallback.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});

  final String? url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    final letter = Text(
      fallback.isEmpty ? '?' : String.fromCharCode(fallback.runes.first).toUpperCase(),
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.accent),
    );
    if (url == null) return letter;
    return ClipOval(
      child: Image.network(
        url!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: letter),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : Center(child: letter),
      ),
    );
  }
}
