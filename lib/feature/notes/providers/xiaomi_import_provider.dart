import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_list_provider.dart';

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
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );

      if (result == null || result.files.isEmpty) {
        state = const XiaomiImportState();
        return false;
      }

      final files = result.files.take(50).toList(); // Limit to 50
      final noteRepository = ref.read(noteRepositoryProvider);

      for (var file in files) {
        if (file.path == null) continue;

        final fileObj = File(file.path!);
        String content = await fileObj.readAsString();

        // Extract title
        String title = 'Untitled Note';
        final titleRegex = RegExp(r'^## Title:\s*(.*)$', multiLine: true);
        final titleMatch = titleRegex.firstMatch(content);
        if (titleMatch != null) {
          title = titleMatch.group(1)?.trim() ?? 'Untitled Note';
          if (title.toLowerCase() == 'untitled note') {
            title = 'Untitled Note';
          }
          // Remove title line
          content = content.replaceFirst(titleMatch.group(0)!, '');
        }

        // Clean up leading **** or spaces
        content = content.replaceFirst(
          RegExp(r'^\*+\s*', multiLine: false),
          '',
        );
        // Clean up Created At text
        content = content.replaceAll(
          RegExp(
            r'\**(Created at:\s*)?\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}\**',
            multiLine: true,
          ),
          '',
        );
        // Clean up trailing and leading newlines
        content = content.trim();

        // Extract Date from filename
        // e.g. note_08-12-2024_12-19-00_0178.md
        DateTime? createdAt;
        final filename = file.name;
        final dateRegex = RegExp(
          r'note_(\d{2})-(\d{2})-(\d{4})_(\d{2})-(\d{2})-(\d{2})',
        );
        final dateMatch = dateRegex.firstMatch(filename);
        if (dateMatch != null) {
          final day = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final year = int.parse(dateMatch.group(3)!);
          final hour = int.parse(dateMatch.group(4)!);
          final minute = int.parse(dateMatch.group(5)!);
          final second = int.parse(dateMatch.group(6)!);
          try {
            createdAt = DateTime(year, month, day, hour, minute, second);
          } catch (e) {
            logError('Failed to parse date from filename: $filename', e);
          }
        }

        await noteRepository.saveNote(
          title: title,
          content: content,
          createdAt: createdAt,
          updatedAt: createdAt,
        );
      }

      ref.invalidate(noteListNotifierProvider);

      state = const XiaomiImportState();
      return true;
    } catch (e, st) {
      logError('Failed to import Xiaomi notes', e, st);
      state = XiaomiImportState(mutationError: e);
      return false;
    }
  }

  Future<void> importXiaomiNotesFromFolder() async {
    if (state.isImportingFolder) return;

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

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
        state = const XiaomiImportState();
        return;
      }

      final total = mdFiles.length;
      state = state.copyWith(totalFiles: total, processedFiles: 0);

      final notificationService = ref.read(notificationServiceProvider);
      const notificationId = 888; // arbitrary fixed ID

      await notificationService.showProgressNotification(
        id: notificationId,
        title: LocalizationExtension.current.notesImportingNotes,
        body: '0 / $total',
        maxProgress: total,
        progress: 0,
      );

      final noteRepository = ref.read(noteRepositoryProvider);
      int processed = 0;

      for (var file in mdFiles) {
        String content = await file.readAsString();

        // Extract title
        String title = 'Untitled Note';
        final titleRegex = RegExp(r'^## Title:\s*(.*)$', multiLine: true);
        final titleMatch = titleRegex.firstMatch(content);
        if (titleMatch != null) {
          title = titleMatch.group(1)?.trim() ?? 'Untitled Note';
          if (title.toLowerCase() == 'untitled note') {
            title = 'Untitled Note';
          }
          // Remove title line
          content = content.replaceFirst(titleMatch.group(0)!, '');
        }

        // Clean up leading **** or spaces
        content = content.replaceFirst(
          RegExp(r'^\*+\s*', multiLine: false),
          '',
        );
        // Clean up Created At text
        content = content.replaceAll(
          RegExp(
            r'\**(Created at:\s*)?\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}\**',
            multiLine: true,
          ),
          '',
        );
        // Clean up trailing and leading newlines
        content = content.trim();

        // Extract Date from filename
        // e.g. note_08-12-2024_12-19-00_0178.md
        DateTime? createdAt;
        final filename = file.uri.pathSegments.last;
        final dateRegex = RegExp(
          r'note_(\d{2})-(\d{2})-(\d{4})_(\d{2})-(\d{2})-(\d{2})',
        );
        final dateMatch = dateRegex.firstMatch(filename);
        if (dateMatch != null) {
          final day = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final year = int.parse(dateMatch.group(3)!);
          final hour = int.parse(dateMatch.group(4)!);
          final minute = int.parse(dateMatch.group(5)!);
          final second = int.parse(dateMatch.group(6)!);
          try {
            createdAt = DateTime(year, month, day, hour, minute, second);
          } catch (e) {
            logError('Failed to parse date from filename: $filename', e);
          }
        }

        await noteRepository.saveNote(
          title: title,
          content: content,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        processed++;

        // Update UI state less frequently to avoid ui lag, but keep it updated
        if (processed % 10 == 0 || processed == total) {
          state = state.copyWith(processedFiles: processed);
          await notificationService.showProgressNotification(
            id: notificationId,
            title: LocalizationExtension.current.notesImportingNotes,
            body: '$processed / $total',
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
    } catch (e, st) {
      logError('Failed to import Xiaomi notes from folder', e, st);
      state = XiaomiImportState(mutationError: e);
      await ref.read(notificationServiceProvider).cancelNotification(888);
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
