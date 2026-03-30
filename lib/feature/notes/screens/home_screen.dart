import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_providers.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_search_field.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listStateAsync = ref.watch(noteListNotifierProvider);
    final isGridView = ref.watch(isGridViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              ref.read(isGridViewProvider.notifier).toggle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/note-editor'),
        child: const Icon(Icons.add),
      ),
      body: ScreenWrapper(
        child: Column(
          children: [
            AppSearchField<dynamic>(
              name: 'search',
              hintText: 'Search notes...',
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
                    return const Center(child: Text('No notes found.'));
                  }
                  return isGridView ? _buildGrid(notes) : _buildList(notes);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Note> notes) {
    return ListView.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return ListTile(
          title: Text(note.title),
          subtitle: Text('Tags: ${note.tags.join(', ')}'),
          onTap: () {
            // we will pass the id to edit it
            context.push('/note-editor', extra: {'id': note.id});
          },
        );
      },
    );
  }

  Widget _buildGrid(List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return InkWell(
          onTap: () {
            context.push('/note-editor', extra: {'id': note.id});
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: context.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tags: ${note.tags.join(', ')}',
                  style: context.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
