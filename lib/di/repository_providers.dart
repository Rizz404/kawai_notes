import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/repositories/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final objectBoxService = ref.watch(objectBoxServiceProvider);
  final noteFileService = ref.watch(noteFileServiceProvider);
  return NoteRepository(objectBoxService, noteFileService);
});
