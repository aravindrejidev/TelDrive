import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../providers/upload_provider.dart';
import '../../services/permission_service.dart';
import '../../utils/constants.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_card.dart';
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
  int _currentIndex = 0;

  static const _categories = [
    FileCategory.photo,
    FileCategory.video,
    FileCategory.audio,
    FileCategory.document,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final category = _categories[_currentIndex];
    final hasAccess = await PermissionService.instance.requestMediaAccess();
    if (!hasAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is needed to pick files.')),
      );
      return;
    }
    if (!mounted) return;
    await context.read<UploadProvider>().pickAndUpload(
          category: category,
          fileProvider: context.read<FileProvider>(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _categories.map((c) => Tab(text: c.label)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<UploadProvider>(
            builder: (context, uploadProvider, _) => UploadProgressList(
              tasks: uploadProvider.tasks,
              onDismiss: uploadProvider.dismissTask,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((c) => _CategoryTab(category: c)).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startUpload,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Upload'),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({required this.category});

  final FileCategory category;

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, _) {
        final files = fileProvider.filesFor(category);

        if (fileProvider.isLoading && files.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (files.isEmpty) {
          return RefreshIndicator(
            onRefresh: fileProvider.loadAll,
            child: ListView(
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: _emptyIcon(category),
                  title: 'No ${category.label.toLowerCase()} yet',
                  message: 'Tap Upload to add your first file. It will stay '
                      'available here even if you delete it from your phone.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: fileProvider.loadAll,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final item = files[index];
              return FileCard(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FilePreviewScreen(item: item)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _emptyIcon(FileCategory category) => switch (category) {
        FileCategory.photo => Icons.photo_library_outlined,
        FileCategory.video => Icons.video_library_outlined,
        FileCategory.audio => Icons.library_music_outlined,
        FileCategory.document => Icons.folder_open_rounded,
      };
}
