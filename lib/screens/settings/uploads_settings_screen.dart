import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/upload_provider.dart';
import '../../theme/neu_theme.dart';
import '../../widgets/neu/neu_controls.dart';
import 'settings_widgets.dart';

class UploadsSettingsScreen extends StatelessWidget {
  const UploadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final uploads = context.read<UploadProvider>();
    final c = context.neu;

    return SettingsPage(
      title: 'Uploads',
      children: [
        const NeuSectionTitle('Quality'),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: Icons.high_quality_rounded,
              title: 'Original photo quality',
              subtitle: 'Send photos as files so Telegram does not compress them.',
              value: settings.keepPhotoOriginal,
              onChanged: settings.setKeepPhotoOriginal,
            ),
          ],
        ),
        const SettingsNote(
          'With this off, photos go out as normal Telegram pictures, which are '
          'smaller but lose detail and cannot be over 10 MB.',
        ),
        const NeuSectionTitle('Notifications'),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: Icons.notifications_off_rounded,
              title: 'Silent uploads',
              subtitle: 'Do not make Telegram notify the channel for every file.',
              value: settings.silentUploads,
              onChanged: settings.setSilentUploads,
            ),
          ],
        ),
        const NeuSectionTitle('Speed'),
        SettingsCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Uploads at the same time',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
              ),
            ),
            NeuSegmented<int>(
              selected: settings.maxConcurrentUploads,
              onChanged: (count) {
                settings.setMaxConcurrentUploads(count);
                uploads.maxConcurrent = count;
              },
              options: const [
                NeuSegment(value: 1, label: '1'),
                NeuSegment(value: 2, label: '2'),
                NeuSegment(value: 3, label: '3'),
                NeuSegment(value: 4, label: '4'),
              ],
            ),
          ],
        ),
        const SettingsNote(
          'More at once is faster on a good connection, but can run into '
          'Telegram\'s rate limit on very large batches.',
        ),
        const SettingsNote(
          'Telegram lets a bot upload files up to 50 MB. Bigger files are '
          'skipped and reported.',
        ),
      ],
    );
  }
}
