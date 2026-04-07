import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/feature/folders/widgets/folder_drawer.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_providers.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_drawer.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_search_field.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

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

  void _onBatchDelete() {
    ref
        .read(noteListNotifierProvider.notifier)
        .deleteNotes(_selectedIds.toList());
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
                    return isGridView ? _buildGrid(notes) : _buildList(notes);
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

  Widget _buildList(List<Note> notes) {
    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isUntitled = note.title == 'Untitled';
        final isSelected = _selectedIds.contains(note.id);
        return ListTile(
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
                        style: isUntitled ? AppTextStyle.bodyMedium : AppTextStyle.bodySmall,
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
          trailing: note.isPinned
              ? Icon(
                  Icons.push_pin,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                )
              : null,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(note.id);
              return;
            }
            // we will pass the id to edit it
            context.push('/note-editor', extra: {'id': note.id});
          },
        );
      },
    );
  }

  Widget _buildGrid(List<Note> notes) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isUntitled = note.title == 'Untitled';
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colorScheme.primary.withValues(alpha: 0.1)
                  : null,
              border: Border.all(
                color: isSelected
                    ? context.colorScheme.primary
                    : context.colors.border,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
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
                    Expanded(
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
                                maxLines: isUntitled ? 8 : 4,
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
                if (note.isPinned)
                  Positioned(
                    top: -8,
                    right: _isSelectionMode ? 24 : -8,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.push_pin,
                        size: 20,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
