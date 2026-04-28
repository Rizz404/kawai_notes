import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class XiaomiImportState extends Equatable {
  final bool isMutating;
  final Object? mutationError;
  final int totalFiles;
  final int processedFiles;
  final bool isImportingFolder;

  const XiaomiImportState({
    this.isMutating = false,
    this.mutationError,
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.isImportingFolder = false,
  });

  @override
  List<Object?> get props => [
    isMutating,
    mutationError,
    totalFiles,
    processedFiles,
    isImportingFolder,
  ];
}

final xiaomiImportProvider =
    NotifierProvider.autoDispose<XiaomiImportNotifier, XiaomiImportState>(
      XiaomiImportNotifier.new,
    );

class XiaomiImportNotifier extends Notifier<XiaomiImportState> {
  @override
  XiaomiImportState build() => const XiaomiImportState();

  Future<bool> importXiaomiNotesBulk() async {
    state = const XiaomiImportState(isMutating: true);

    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: ['md'],
        );
      } on PlatformException catch (e) {
        logError('FilePicker platform error: ${e.code}', e);
        state = XiaomiImportState(mutationError: e);
        return false;
      }

      if (result == null || result.files.isEmpty) {
        state = const XiaomiImportState();
        return false;
      }

      final files = result.files
          .where((f) => f.path != null)
          .take(50)
          .map((f) => File(f.path!))
          .toList(); // Limit to 50
      final xiaomiImportService = ref.read(xiaomiImportServiceProvider);
      final noteRepository = ref.read(noteRepositoryProvider);

      for (var file in files) {
        final parsedNote = await xiaomiImportService.parseFile(file);
        if (parsedNote != null) {
          await noteRepository.saveNote(
            title: parsedNote.title,
            content: parsedNote.content,
            createdAt: parsedNote.createdAt,
            updatedAt: parsedNote.createdAt,
          );
        }
      }

      ref.invalidate(noteListNotifierProvider);

      state = const XiaomiImportState();
      return true;
    } catch (e, st) {
      logError('Failed to import Xiaomi notes', e, st);
      state = XiaomiImportState(mutationError: e);
      // * ensure partial imports are visible even if loop failed midway
      ref.invalidate(noteListNotifierProvider);
      return false;
    }
  }

  Future<bool> importXiaomiNotesFromFolder({
    required String importingNotesTitle,
  }) async {
    if (state.isImportingFolder) return false;

    try {
      if (Platform.isAndroid) {
        final storageStatus = await Permission.manageExternalStorage.status;
        if (!storageStatus.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            final storageStatus2 = await Permission.storage.status;
            if (!storageStatus2.isGranted) {
              final result2 = await Permission.storage.request();
              if (!result2.isGranted) {
                state = const XiaomiImportState(
                  mutationError: 'Storage permission required',
                );
                return false;
              }
            }
          }
        }
      }

      String? selectedDirectory;
      try {
        selectedDirectory = await FilePicker.platform.getDirectoryPath();
      } on PlatformException catch (e) {
        logError('FilePicker platform error: ${e.code}', e);
        state = XiaomiImportState(mutationError: e);
        return false;
      }

      if (selectedDirectory == null) return false;

      state = const XiaomiImportState(
        isMutating: true,
        isImportingFolder: true,
      );

      final dir = Directory(selectedDirectory);
      final entities = await dir.list(recursive: true).toList();
      final mdFiles = entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();

      if (mdFiles.isEmpty) {
        state = const XiaomiImportState(
          mutationError: 'No markdown files found',
        );
        return false;
      }

      final total = mdFiles.length;
      state = state.copyWith(totalFiles: total, processedFiles: 0);

      final notificationService = ref.read(notificationServiceProvider);
      const notificationId = 888; // arbitrary fixed ID

      await notificationService.showProgressNotification(
        id: notificationId,
        title: importingNotesTitle,
        body: '0 / $total',
        maxProgress: total,
        progress: 0,
      );

      final xiaomiImportService = ref.read(xiaomiImportServiceProvider);
      final noteRepository = ref.read(noteRepositoryProvider);

      int processed = 0;

      for (var file in mdFiles) {
        final parsedNote = await xiaomiImportService.parseFile(file);
        if (parsedNote != null) {
          await noteRepository.saveNote(
            title: parsedNote.title,
            content: parsedNote.content,
            createdAt: parsedNote.createdAt,
            updatedAt: parsedNote.createdAt,
          );
        }

        processed++;
        String currentTitle = parsedNote?.title ?? 'Skipped';

        if (processed % 10 == 0 || processed == total) {
          state = state.copyWith(processedFiles: processed);
          await notificationService.showProgressNotification(
            id: notificationId,
            title: importingNotesTitle,
            body: '$processed / $total - $currentTitle',
            maxProgress: total,
            progress: processed,
          );
          // Yield to framework
          await Future<void>.delayed(Duration.zero);
        }
      }

      // Hide progress notification
      await notificationService.cancelNotification(notificationId);
      ref.invalidate(noteListNotifierProvider);

      state = const XiaomiImportState();
      return true;
    } catch (e, st) {
      logError('Failed to import Xiaomi notes from folder', e, st);
      state = XiaomiImportState(mutationError: e);
      // * ensure partial imports are visible even if loop failed midway
      ref.invalidate(noteListNotifierProvider);
      await ref.read(notificationServiceProvider).cancelNotification(888);
      return false;
    }
  }
}

extension XiaomiImportStateX on XiaomiImportState {
  XiaomiImportState copyWith({
    bool? isMutating,
    Object? mutationError,
    int? totalFiles,
    int? processedFiles,
    bool? isImportingFolder,
  }) {
    return XiaomiImportState(
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError ?? this.mutationError,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      isImportingFolder: isImportingFolder ?? this.isImportingFolder,
    );
  }
}
