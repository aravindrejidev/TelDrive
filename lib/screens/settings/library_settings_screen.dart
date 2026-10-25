import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/neu/neu_controls.dart';
import 'settings_widgets.dart';

const List<String> kTabNames = ['Photos', 'Videos', 'Audio', 'Documents'];

const List<IconData> kTabIcons = [
  Icons.photo_library_rounded,
  Icons.videocam_rounded,
  Icons.library_music_rounded,
  Icons.description_rounded,
];

class LibrarySettingsScreen extends StatelessWidget {
  const LibrarySettingsScreen({super.key});

  static IconData _sortIcon(FileSort sort) => switch (sort) {
        FileSort.newest => Icons.schedule_rounded,
        FileSort.oldest => Icons.history_rounded,
        FileSort.name => Icons.sort_by_alpha_rounded,
        FileSort.size => Icons.data_usage_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final files = context.read<FileProvider>();

    return SettingsPage(
      title: 'Library',
      children: [
        const NeuSectionTitle('Sort files by'),
        SettingsCard(
          children: [
            for (final sort in FileSort.values)
              SettingsChoiceRow(
                icon: _sortIcon(sort),
                title: sort.label,
                selected: settings.defaultSort == sort,
                onTap: () {
                  settings.setDefaultSort(sort);
                  // Show the new order straight away as well as next time.
                  files.setSort(sort);
                },
              ),
          ],
        ),
        const SettingsNote('You can still change the order on the home screen at any time.'),
        const NeuSectionTitle('Open on'),
        SettingsCard(
          children: [
            for (var i = 0; i < kTabNames.length; i++)
              SettingsChoiceRow(
                icon: kTabIcons[i],
                title: kTabNames[i],
                selected: settings.startTabIndex == i,
                onTap: () => settings.setStartTabIndex(i),
              ),
          ],
        ),
        const SettingsNote('The tab that is shown when the app starts.'),
        const NeuSectionTitle('Display and safety'),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: Icons.image_rounded,
              title: 'Photo thumbnails',
              subtitle: 'Show a small picture for photos that are on this phone.',
              value: settings.showThumbnails,
              onChanged: settings.setShowThumbnails,
            ),
            SettingsSwitchRow(
              icon: Icons.gpp_maybe_rounded,
              title: 'Confirm permanent delete',
              subtitle: 'Ask once more before a file is deleted from Telegram.',
              value: settings.confirmPermanentDelete,
              onChanged: settings.setConfirmPermanentDelete,
            ),
          ],
        ),
      ],
    );
  }
}
