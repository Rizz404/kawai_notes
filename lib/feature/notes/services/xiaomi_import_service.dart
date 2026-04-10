import 'dart:io';

import 'package:kawai_notes/core/extensions/logger_extension.dart';

class ParsedXiaomiNote {
  final String title;
  final String content;
  final DateTime? createdAt;
  
  const ParsedXiaomiNote({
    required this.title,
    required this.content,
    this.createdAt,
  });
}

class XiaomiImportService {
  Future<ParsedXiaomiNote?> parseFile(File file) async {
    if (!await file.exists()) return null;

    String content = await file.readAsString();

    // Extract title
    String title = 'Untitled';
    final titleRegex = RegExp(r'^## Title:\s*(.*)$', multiLine: true);
    final titleMatch = titleRegex.firstMatch(content);
    if (titleMatch != null) {
      title = titleMatch.group(1)?.trim() ?? 'Untitled';
      if (title.toLowerCase() == 'untitled note') {
        title = 'Untitled';
      }
      // Remove title line
      content = content.replaceFirst(titleMatch.group(0)!, '');
    }

    // Clean up leading **** or spaces
    content = content.replaceFirst(RegExp(r'^\*+\s*', multiLine: false), '');
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

    return ParsedXiaomiNote(
      title: title,
      content: content,
      createdAt: createdAt,
    );
  }
}
