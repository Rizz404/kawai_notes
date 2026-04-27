import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/folders/widgets/folder_drawer.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/shared/widgets/app_drawer.dart';
import 'package:kawai_notes/shared/widgets/app_search_field.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<int> _selectedIds = {};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  Future<void> _handleRefresh() async {
    final auth = ref.read(authServiceProvider);
    final isAuth = await auth.authenticate(
      reason: 'Verify identity to view hidden notes',
    );
    if (isAuth && mounted) {
      context.push('/hidden-notes');
    }
  }

  void _onBatchHide() {
    ref
        .read(noteListNotifierProvider.notifier)
        .hideNotes(_selectedIds.toList());
    _clearSelection();
  }

  void _onBatchPin() {
    // * cek apakah semua sudah di-pin; kalau iya, unpin semua
    final listState = ref.read(noteListNotifierProvider).value;
    final notes = listState?.items ?? [];
    final selectedNotes = notes.where((n) => _selectedIds.contains(n.id));
    final allPinned = selectedNotes.every((n) => n.isPinned);
    ref
        .read(noteListNotifierProvider.notifier)
        .pinNotes(_selectedIds.toList(), isPinned: !allPinned);
    _clearSelection();
  }

  void _onBatchDelete() {
    ref
        .read(noteListNotifierProvider.notifier)
        .deleteNotes(_selectedIds.toList());
    _clearSelection();
  }

  Future<void> _onBatchPickColor() async {
    final Color newColor = await showColorPickerDialog(
      context,
      Colors.white,
      title: AppText(context.l10n.notesPickColor, fontSize: 20),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: true,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    );

    ref.read(noteListNotifierProvider.notifier).batchUpdateBackground(
      _selectedIds.toList(),
      colorValue: newColor.value,
      customBackgroundImage: null,
    );
    _clearSelection();
  }

  Future<void> _onBatchPickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final extension = path.extension(pickedFile.path);
      final newPath = path.join(appDir.path, 'note_bg_batch_${DateTime.now().millisecondsSinceEpoch}$extension');
      await File(pickedFile.path).copy(newPath);

      ref.read(noteListNotifierProvider.notifier).batchUpdateBackground(
        _selectedIds.toList(),
        colorValue: null,
        customBackgroundImage: newPath,
      );
      _clearSelection();
    }
  }

  void _onBatchResetBackground() {
    ref.read(noteListNotifierProvider.notifier).batchUpdateBackground(
      _selectedIds.toList(),
      colorValue: null,
      customBackgroundImage: null,
    );
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final listStateAsync = ref.watch(noteListNotifierProvider);
    final isGridView = ref.watch(isGridViewProvider);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: AppText(
                context.l10n.notesSelectedCount(_selectedIds.length),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: _onBatchPickColor,
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _onBatchPickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.format_color_reset),
                  onPressed: _onBatchResetBackground,
                ),
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined),
                  onPressed: _onBatchPin,
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_off),
                  onPressed: _onBatchHide,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _onBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: AppText(context.l10n.notesMyTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.hub_outlined),
                  onPressed: () => context.push('/graph-view'),
                ),
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.folder_outlined),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
                IconButton(
                  icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    ref.read(isGridViewProvider.notifier).toggle();
                  },
                ),
              ],
            ),
      endDrawer: const FolderDrawer(),
      drawer: const AppDrawer(),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/note-editor'),
              backgroundColor: context.colorScheme.primary,
              child: Icon(Icons.add, color: context.colorScheme.onPrimary),
            ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ScreenWrapper(
          child: Column(
            children: [
              AppSearchField<dynamic>(
                name: 'search',
                hintText: context.l10n.notesSearchNotes,
                onChanged: (value) {
                  ref.read(noteListNotifierProvider.notifier).search(value);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: listStateAsync.when(
                  data: (state) {
                    final notes = state.items;
                    if (notes.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 100),
                          Center(child: AppText(context.l10n.notesNotFound)),
                        ],
                      );
                    }
                    final pinned = notes.where((n) => n.isPinned).toList();
                    final unpinned = notes.where((n) => !n.isPinned).toList();
                    return isGridView
                        ? _buildGrid(pinned, unpinned)
                        : _buildList(pinned, unpinned);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: AppText(context.l10n.notesError(error.toString())),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Note> pinned, List<Note> unpinned) {
    final hasPinned = pinned.isNotEmpty;
    return ListView(
      children: [
        if (hasPinned) ..._buildSectionHeader('Pinned'),
        if (hasPinned) ...pinned.map(_buildListTile),
        if (hasPinned && unpinned.isNotEmpty) ..._buildSectionHeader('Notes'),
        ...unpinned.map(_buildListTile),
      ],
    );
  }

  List<Widget> _buildSectionHeader(String label) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AppText(
        label,
        style: AppTextStyle.labelMedium,
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  ];

  Widget _buildListTile(Note note) {
    final isUntitled =
        note.title == 'Untitled' ||
        note.title == context.l10n.notesUntitledNote;
    final isSelected = _selectedIds.contains(note.id);
    final hasBackground = note.colorValue != null || note.customBackgroundImage != null;

    final childTile = ListTile(
      selected: isSelected,
      onLongPress: () => _toggleSelection(note.id),
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(note.id),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUntitled)
            AppText(
              note.title,
              style: AppTextStyle.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Consumer(
            builder: (context, ref, _) {
              final previewAsync = ref.watch(notePreviewProvider(note.id));
              return previewAsync.when(
                data: (content) {
                  if (content.trim().isEmpty && isUntitled) {
                    return AppText(
                      context.l10n.notesNoContent,
                      style: AppTextStyle.bodyMedium,
                      fontStyle: FontStyle.italic,
                    );
                  }
                  return AppText(
                    content.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: isUntitled
                        ? AppTextStyle.bodyMedium
                        : AppTextStyle.bodySmall,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
      subtitle: note.tags.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: AppText(
                context.l10n.notesTags(note.tags.join(', ')),
                style: AppTextStyle.labelSmall,
              ),
            )
          : null,
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(note.id);
          return;
        }
        context.push('/note-editor', extra: {'id': note.id});
      },
    );

    if (hasBackground) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: note.colorValue != null ? Color(note.colorValue!) : null,
          image: note.customBackgroundImage != null
              ? DecorationImage(
                  image: FileImage(File(note.customBackgroundImage!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
          border: (hasBackground && !isSelected)
              ? const Border()
              : Border.all(
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: childTile,
      );
    }
    return childTile;
  }

  Widget _buildGrid(List<Note> pinned, List<Note> unpinned) {
    final hasPinned = pinned.isNotEmpty;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (hasPinned) ...[
          SliverToBoxAdapter(child: _buildSectionHeader('Pinned').first),
          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childCount: pinned.length,
              itemBuilder: (context, i) => _buildGridCard(pinned[i]),
            ),
          ),
        ],
        if (hasPinned && unpinned.isNotEmpty)
          SliverToBoxAdapter(child: _buildSectionHeader('Notes').first),
        if (unpinned.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childCount: unpinned.length,
              itemBuilder: (context, i) => _buildGridCard(unpinned[i]),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildGridCard(Note note) {
    final isUntitled =
        note.title == 'Untitled' ||
        note.title == context.l10n.notesUntitledNote;
    final isSelected = _selectedIds.contains(note.id);
    return InkWell(
      onLongPress: () => _toggleSelection(note.id),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(note.id);
          return;
        }
        context.push('/note-editor', extra: {'id': note.id});
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 100, maxHeight: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: note.colorValue != null
              ? Color(note.colorValue!)
              : (isSelected
                  ? context.colorScheme.primary.withValues(alpha: 0.1)
                  : context.colors.surface),
          image: note.customBackgroundImage != null
              ? DecorationImage(
                  image: FileImage(File(note.customBackgroundImage!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
          border: ((note.colorValue != null || note.customBackgroundImage != null) && !isSelected)
              ? const Border()
              : Border.all(
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUntitled) ...[
                  AppText(
                    note.title,
                    style: AppTextStyle.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final previewAsync = ref.watch(
                        notePreviewProvider(note.id),
                      );
                      return previewAsync.when(
                        data: (content) {
                          if (content.trim().isEmpty && isUntitled) {
                            return AppText(
                              context.l10n.notesNoContent,
                              style: AppTextStyle.bodyMedium,
                              fontStyle: FontStyle.italic,
                            );
                          }
                          return AppText(
                            content.trim(),
                            style: AppTextStyle.bodyMedium,
                            maxLines: isUntitled ? 24 : 20,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (err, stack) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppText(
                    context.l10n.notesTags(note.tags.join(', ')),
                    style: AppTextStyle.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                top: -8,
                right: -8,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(note.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
