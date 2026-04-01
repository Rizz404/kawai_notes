import 'dart:io';
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_list_provider.dart';

class XiaomiImportState extends Equatable {
  final bool isMutating;
  final Object? mutationError;

  const XiaomiImportState({this.isMutating = false, this.mutationError});

  @override
  List<Object?> get props => [isMutating, mutationError];
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
        // Clean up leading newlines
        content = content.trimLeft();

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
}
