import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  final ObjectBoxService _objectBoxService;
  final SharedPreferences _prefs;

  BackupService(this._objectBoxService, this._prefs);

  static const String _lastBackupKey = 'last_auto_backup_date';

  Future<Directory> _getDocsDir() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<bool> runAutoBackup() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final lastBackup = _prefs.getString(_lastBackupKey);

      if (lastBackup == todayStr) {
        return false; // Already backed up today
      }

      final docsDir = await _getDocsDir();
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));

      final zipPath = p.join(docsDir.path, 'auto_backup.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      if (await dbDir.exists()) {
        encoder.addDirectory(dbDir);
      }
      if (await notesDir.exists()) {
        encoder.addDirectory(notesDir);
      }
      encoder.close();

      await _prefs.setString(_lastBackupKey, todayStr);
      AppLogger.instance.info('Auto backup successful for $todayStr');
      return true;
    } catch (e, stack) {
      AppLogger.instance.error('Auto backup error', e, stack);
      return false;
    }
  }

  Future<bool> hasAutoBackup() async {
    final docsDir = await _getDocsDir();
    final file = File(p.join(docsDir.path, 'auto_backup.zip'));
    return await file.exists();
  }

  Future<DateTime?> getAutoBackupDate() async {
    final docsDir = await _getDocsDir();
    final file = File(p.join(docsDir.path, 'auto_backup.zip'));
    if (await file.exists()) {
      return await file.lastModified();
    }
    return null;
  }

  Future<bool> restoreFromAutoBackup() async {
    try {
      final docsDir = await _getDocsDir();
      final zipPath = p.join(docsDir.path, 'auto_backup.zip');
      final file = File(zipPath);

      if (!await file.exists()) return false;

      // 1. Close store
      _objectBoxService.store.close();

      // 2. Clear old directories
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));
      if (await dbDir.exists()) {
        await dbDir.delete(recursive: true);
      }
      if (await notesDir.exists()) {
        await notesDir.delete(recursive: true);
      }

      // 3. Extract new
      extractFileToDisk(zipPath, docsDir.path);

      // 4. Reopen store
      await _objectBoxService.restartStore();
      return true;
    } catch (e, stack) {
      AppLogger.instance.error('Restore from auto backup error', e, stack);
      // Try to restart store in case it failed midway
      await _objectBoxService.restartStore();
      return false;
    }
  }

  Future<bool> exportBackupManual() async {
    try {
      final docsDir = await _getDocsDir();
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));

      final zipPath = p.join(docsDir.path, 'temp_export.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      if (await dbDir.exists()) {
        encoder.addDirectory(dbDir);
      }
      if (await notesDir.exists()) {
        encoder.addDirectory(notesDir);
      }
      encoder.close();

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'kawai_notes_backup_$dateStr.zip';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (outputPath != null) {
        final tempFile = File(zipPath);
        await tempFile.copy(outputPath);
        await tempFile.delete();
        return true;
      } else {
        // User canceled
        final tempFile = File(zipPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return false;
      }
    } catch (e, stack) {
      AppLogger.instance.error('Backup export error', e, stack);
      return false;
    }
  }

  Future<bool> importBackupManual() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        final zipPath = result.files.single.path!;
        final docsDir = await _getDocsDir();

        // 1. Close store
        _objectBoxService.store.close();

        // 2. Clear old directories
        final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
        final notesDir = Directory(p.join(docsDir.path, 'notes'));
        try {
          if (await dbDir.exists()) await dbDir.delete(recursive: true);
          if (await notesDir.exists()) await notesDir.delete(recursive: true);
        } catch (e) {
          AppLogger.instance.error(
            'Failed to fully delete old db, ignoring to let extract overwrite',
            e,
          );
        }

        // 3. Extract new
        extractFileToDisk(zipPath, docsDir.path);

        // 4. Reopen store
        await _objectBoxService.restartStore();
        return true;
      }
      return false;
    } catch (e, stack) {
      AppLogger.instance.error('Backup import error', e, stack);
      await _objectBoxService.restartStore();
      return false;
    }
  }
}
