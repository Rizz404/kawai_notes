import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/folders/repositories/folder_repository.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final objectBoxService = ref.watch(objectBoxServiceProvider);
  final noteFileService = ref.watch(noteFileServiceProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);
  return NoteRepository(objectBoxService, noteFileService, encryptionService);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final objectBoxService = ref.watch(objectBoxServiceProvider);
  return TaskRepository(objectBoxService);
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  final objectBoxService = ref.watch(objectBoxServiceProvider);
  return FolderRepository(objectBoxService);
});
