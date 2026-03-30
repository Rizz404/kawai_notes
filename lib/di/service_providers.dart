import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/services/language_storage_service.dart';
import 'package:flutter_setup_riverpod/core/services/note_file_service.dart';
import 'package:flutter_setup_riverpod/core/services/objectbox_service.dart';
import 'package:flutter_setup_riverpod/core/services/theme_storage_service.dart';
import 'package:flutter_setup_riverpod/di/common_providers.dart';

final languageStorageServiceProvider = Provider<LanguageStorageService>((ref) {
  final _sharedPreferences = ref.watch(sharedPreferencesProvider);
  return LanguageStorageServiceImpl(_sharedPreferences);
});

final themeStorageServiceProvider = Provider<ThemeStorageService>((ref) {
  final _sharedPreferences = ref.watch(sharedPreferencesProvider);
  return ThemeStorageServiceImpl(_sharedPreferences);
});
final objectBoxServiceProvider = Provider<ObjectBoxService>((ref) {
  throw UnimplementedError();
});
final noteFileServiceProvider = Provider<NoteFileService>((ref) {
  return NoteFileService();
});
