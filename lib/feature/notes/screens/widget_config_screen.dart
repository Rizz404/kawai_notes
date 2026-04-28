import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/markdown_parser_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/core/utils/toast_utils.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
import 'package:kawai_notes/feature/notes/services/note_widget_service.dart';

class NoteWidgetConfigScreen extends ConsumerStatefulWidget {
  final int widgetId;

  const NoteWidgetConfigScreen({super.key, required this.widgetId});

  @override
  ConsumerState<NoteWidgetConfigScreen> createState() =>
      _NoteWidgetConfigScreenState();
}

class _NoteWidgetConfigScreenState
    extends ConsumerState<NoteWidgetConfigScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _savingNoteId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectNote(Note note) async {
    setState(() => _savingNoteId = note.id);
    try {
      final repo = ref.read(noteRepositoryProvider);
      final content = await repo.getNoteContent(note);
      final preview = content.toPlainText();
      final prefs = ref.read(sharedPreferencesProvider);

      await NoteWidgetService.saveWidget(
        prefs: prefs,
        widgetId: widget.widgetId,
        note: note,
        contentPreview: preview,
      );

      if (mounted) {
        AppToast.success('Widget berhasil diperbarui!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error('Gagal menyimpan widget: $e');
      }
    } finally {
      if (mounted) setState(() => _savingNoteId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(noteListNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih catatan untuk widget'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Cari catatan...',
              leading: const Icon(Icons.search),
              trailing: _query.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ]
                  : null,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) {
          final notes = _query.isEmpty
              ? state.items
              : state.items
                    .where(
                      (n) =>
                          n.title.toLowerCase().contains(_query) ||
                          n.tags.any((t) => t.toLowerCase().contains(_query)) ||
                          (n.content?.toLowerCase().contains(_query) ?? false),
                    )
                    .toList();

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _query.isEmpty
                        ? 'Belum ada catatan'
                        : 'Catatan tidak ditemukan',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final note = notes[index];
              final isSaving = _savingNoteId == note.id;
              final noteColor =
                  note.colorValue != null ? Color(note.colorValue!) : null;

              return Card(
                color: noteColor?.withValues(alpha: 0.15) ??
                    colorScheme.surfaceContainerHighest,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: noteColor ?? colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    note.title.isEmpty ? '(Tanpa judul)' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: note.tags.isNotEmpty
                      ? Wrap(
                          spacing: 4,
                          children: note.tags
                              .take(3)
                              .map(
                                (t) => Chip(
                                  label: Text(
                                    '#$t',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        )
                      : null,
                  trailing: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_to_home_screen),
                  onTap: isSaving ? null : () => _selectNote(note),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
