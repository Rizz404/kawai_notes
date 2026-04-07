import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  final ObjectBoxService _objectBoxService;
  final SharedPreferences _prefs;
  final NotificationService _notificationService;

  BackupService(
    this._objectBoxService,
    this._prefs,
    this._notificationService,
  );

  static const String _lastBackupKey = 'last_auto_backup_date';
  static const String _autoBackupFolderKey = 'auto_backup_folder';
  static const String _autoBackupHourKey = 'auto_backup_time_hour';
  static const String _autoBackupMinuteKey = 'auto_backup_time_minute';

  // * Default jadwal: 02:00
  static const int _defaultHour = 2;
  static const int _defaultMinute = 0;

  Future<Directory> _getDocsDir() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Path zip file auto backup (folder kustom atau docs dir fallback)
  Future<String> _getAutoBackupZipPath() async {
    final folder = getAutoBackupFolder();
    if (folder != null && await Directory(folder).exists()) {
      return p.join(folder, 'kawai_notes_auto_backup.zip');
    }
    final docsDir = await _getDocsDir();
    return p.join(docsDir.path, 'kawai_notes_auto_backup.zip');
  }

  // --- Getters ---

  String? getAutoBackupFolder() => _prefs.getString(_autoBackupFolderKey);

  TimeOfDay getAutoBackupTime() {
    final hour = _prefs.getInt(_autoBackupHourKey) ?? _defaultHour;
    final minute = _prefs.getInt(_autoBackupMinuteKey) ?? _defaultMinute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  // --- Setters ---

  Future<void> setAutoBackupFolder(String? path) async {
    if (path == null) {
      await _prefs.remove(_autoBackupFolderKey);
    } else {
      await _prefs.setString(_autoBackupFolderKey, path);
    }
  }

  Future<void> setAutoBackupTime(int hour, int minute) async {
    await _prefs.setInt(_autoBackupHourKey, hour);
    await _prefs.setInt(_autoBackupMinuteKey, minute);
  }

  // --- Auto Backup ---

  Future<bool> runAutoBackup({bool forceRun = false}) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final lastBackup = _prefs.getString(_lastBackupKey);

      // * Cek apakah sudah backup hari ini
      if (!forceRun && lastBackup == todayStr) {
        return false;
      }

      // * Cek apakah sudah melewati jadwal waktu
      if (!forceRun) {
        final schedule = getAutoBackupTime();
        final scheduledMinutes = schedule.hour * 60 + schedule.minute;
        final currentMinutes = now.hour * 60 + now.minute;
        if (currentMinutes < scheduledMinutes) {
          return false;
        }
      }

      final docsDir = await _getDocsDir();
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));

      final zipPath = await _getAutoBackupZipPath();
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      if (await dbDir.exists()) {
        await encoder.addDirectory(dbDir);
      }
      if (await notesDir.exists()) {
        await encoder.addDirectory(notesDir);
      }
      await encoder.close();

      await _prefs.setString(_lastBackupKey, todayStr);
      AppLogger.instance.info('Auto backup successful for $todayStr → $zipPath');

      // * Kirim notifikasi
      await _notificationService.showBackupSuccessNotification(
        title: 'Auto Backup',
        body: 'Backup berhasil disimpan (${DateFormat('HH:mm').format(now)})',
      );

      return true;
    } catch (e, stack) {
      AppLogger.instance.error('Auto backup error', e, stack);
      return false;
    }
  }

  Future<bool> hasAutoBackup() async {
    final zipPath = await _getAutoBackupZipPath();
    return await File(zipPath).exists();
  }

  Future<DateTime?> getAutoBackupDate() async {
    final zipPath = await _getAutoBackupZipPath();
    final file = File(zipPath);
    if (await file.exists()) {
      return await file.lastModified();
    }
    return null;
  }

  Future<bool> restoreFromAutoBackup() async {
    try {
      final zipPath = await _getAutoBackupZipPath();
      final file = File(zipPath);

      if (!await file.exists()) return false;

      // 1. Close store
      _objectBoxService.store.close();

      // 2. Clear old directories
      final docsDir = await _getDocsDir();
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));
      if (await dbDir.exists()) {
        await dbDir.delete(recursive: true);
      }
      if (await notesDir.exists()) {
        await notesDir.delete(recursive: true);
      }

      // 3. Extract new
      await extractFileToDisk(zipPath, docsDir.path);

      // 4. Reopen store
      await _objectBoxService.restartStore();
      return true;
    } catch (e, stack) {
      AppLogger.instance.error('Restore from auto backup error', e, stack);
      await _objectBoxService.restartStore();
      return false;
    }
  }

  // --- Manual Backup ---

  Future<bool> exportBackupManual() async {
    try {
      final docsDir = await _getDocsDir();
      final dbDir = Directory(p.join(docsDir.path, 'notes_db'));
      final notesDir = Directory(p.join(docsDir.path, 'notes'));

      final zipPath = p.join(docsDir.path, 'temp_export.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      if (await dbDir.exists()) {
        await encoder.addDirectory(dbDir);
      }
      if (await notesDir.exists()) {
        await encoder.addDirectory(notesDir);
      }
      await encoder.close();

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
        await extractFileToDisk(zipPath, docsDir.path);

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
