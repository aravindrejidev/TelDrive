import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../../providers/upload_provider.dart';
import '../../theme/neu_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/helpers.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_card.dart';
import '../../widgets/neu/neu_controls.dart';
import '../../widgets/neu/neu_route.dart';
import '../../widgets/neu/neu_surface.dart';
import '../../widgets/update/update_sheet.dart';
import '../../widgets/upload_progress_list.dart';
import '../file_preview/file_preview_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  static const _categories = [
    FileCategory.photo,
    FileCategory.video,
    FileCategory.audio,
    FileCategory.document,
  ];

  static const _tabs = [
    NeuTabItem(label: 'Photos', icon: Icons.photo_library_rounded),
    NeuTabItem(label: 'Videos', icon: Icons.videocam_rounded),
    NeuTabItem(label: 'Audio', icon: Icons.library_music_rounded),
    NeuTabItem(label: 'Documents', icon: Icons.description_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: settings.startTabIndex.clamp(0, _categories.length - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Apply the saved preferences, then load the files.
      context.read<FileProvider>().setSort(settings.defaultSort);
      context.read<UploadProvider>().maxConcurrent = settings.maxConcurrentUploads;
      context.read<FileProvider>().loadAll();
      if (settings.autoCheckUpdates) _checkForUpdate();
    });
  }

  /// Looks for a newer release as soon as the app opens. If there is one the
  /// update sheet slides up once the home screen has settled.
  Future<void> _checkForUpdate() async {
    final shouldPrompt = await context.read<UpdateProvider>().checkOnStartup();
    if (!shouldPrompt || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) showUpdateSheet(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final category = _categories[_tabController.index];
    final uploads = context.read<UploadProvider>();
    final files = context.read<FileProvider>();
    try {
      await uploads.pickAndUpload(category: category, fileProvider: files);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the file picker: ${friendlyError(e)}')),
      );
    }
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      context.read<FileProvider>().setQuery('');
    }
  }

  Future<void> _showSortSheet() async {
    final files = context.read<FileProvider>();
    final picked = await showNeuSheet<FileSort>(
      context,
      builder: (sheetContext) {
        final c = sheetContext.neu;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sort files', style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final option in FileSort.values)
              NeuListRow(
                icon: switch (option) {
                  FileSort.newest => Icons.schedule_rounded,
                  FileSort.oldest => Icons.history_rounded,
                  FileSort.name => Icons.sort_by_alpha_rounded,
                  FileSort.size => Icons.data_usage_rounded,
                },
                title: option.label,
                trailing: option == files.sort
                    ? Icon(Icons.check_circle_rounded, color: c.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        );
      },
    );
    if (picked != null) files.setSort(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: _SearchField(
                        controller: _searchController,
                        onChanged: context.read<FileProvider>().setQuery,
                        onClear: () {
                          _searchController.clear();
                          context.read<FileProvider>().setQuery('');
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Consumer<UploadProvider>(
              builder: (context, uploads, _) => UploadProgressList(
                tasks: uploads.tasks,
                onDismiss: uploads.dismissTask,
                onRetry: (id) => uploads.retry(id, context.read<FileProvider>()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: NeuTabs(controller: _tabController, items: _tabs),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [for (final c in _categories) _CategoryTab(category: c)],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: NeuButton(
        label: 'Upload',
        icon: Icons.add_rounded,
        expand: false,
        onPressed: _startUpload,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.neu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          const BrandLogo(size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 25),
                ),
                const SizedBox(height: 1),
                Consumer<FileProvider>(
                  builder: (context, files, _) => Text(
                    files.isLoading && files.totalCount == 0
                        ? 'Loading your files…'
                        : files.totalCount == 0
                            ? 'Your drive on Telegram'
                            : '${files.totalCount} files, ${Formatters.fileSize(files.totalBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            active: _searching,
            onTap: _toggleSearch,
          ),
          const SizedBox(width: 12),
          NeuIconButton(
            icon: Icons.swap_vert_rounded,
            tooltip: 'Sort',
            onTap: _showSortSheet,
          ),
          const SizedBox(width: 12),
          Consumer<UpdateProvider>(
            builder: (context, updates, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                NeuIconButton(
                  icon: Icons.settings_rounded,
                  tooltip: 'Settings',
                  onTap: () => Navigator.of(context).push(
                    neuRoute<void>(const SettingsScreen()),
                  ),
                ),
                // A small dot appears while an update is waiting.
                Positioned(
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: AnimatedScale(
                      scale: updates.hasPendingUpdate ? 1 : 0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: c.accentGradient,
                          border: Border.all(color: c.base, width: 2.5),
                        ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return NeuSurface(
      depth: NeuDepth.inset,
      radius: 22,
      distance: 4,
      blur: 9,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: c.accent,
              style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search by file name',
                hintStyle: TextStyle(
                  color: c.textMuted.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.category});

  final FileCategory category;

  @override
  Widget build(BuildContext context) {
    final c = context.neu;
    return Consumer<FileProvider>(
      builder: (context, fileProvider, _) {
        final files = fileProvider.filesFor(category);
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 112;

        if (fileProvider.isLoading && files.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (files.isEmpty) {
          final searching = fileProvider.query.isNotEmpty;
          return RefreshIndicator(
            onRefresh: fileProvider.loadAll,
            color: c.accent,
            backgroundColor: c.base,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 56, bottom: bottomPadding),
              children: [
                EmptyState(
                  icon: searching ? Icons.search_off_rounded : _emptyIcon(category),
                  title: searching ? 'No matches' : 'No ${category.label.toLowerCase()} yet',
                  message: searching
                      ? 'Nothing here is named like "${fileProvider.query}".'
                      : 'Tap Upload to add your first file. It stays here even '
                          'after you delete it from your phone.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: fileProvider.loadAll,
          color: c.accent,
          backgroundColor: c.base,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 6, bottom: bottomPadding),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final item = files[index];
              return FileCard(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => FilePreviewScreen(item: item)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _emptyIcon(FileCategory category) => switch (category) {
        FileCategory.photo => Icons.photo_library_rounded,
        FileCategory.video => Icons.video_library_rounded,
        FileCategory.audio => Icons.library_music_rounded,
        FileCategory.document => Icons.folder_open_rounded,
      };
}
