import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';

class NotesQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final notesQueryProvider = NotifierProvider<NotesQueryNotifier, String>(
  () => NotesQueryNotifier(),
);

class IsGridViewNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final isGridViewProvider = NotifierProvider<IsGridViewNotifier, bool>(
  () => IsGridViewNotifier(),
);

// Data Providers
final allNotesProvider = Provider<List<Note>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return repository.getAllNotes();
});

final filteredNotesProvider = Provider<List<Note>>((ref) {
  final allNotes = ref.watch(allNotesProvider);
  final query = ref.watch(notesQueryProvider).toLowerCase();

  if (query.isEmpty) {
    return allNotes;
  }

  return allNotes.where((note) {
    return note.title.toLowerCase().contains(query) ||
        note.tags.any((tag) => tag.toLowerCase().contains(query));
  }).toList();
});
