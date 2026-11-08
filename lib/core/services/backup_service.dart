import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upper bounds applied to backup archives before anything is extracted,
/// so a hostile or corrupt zip cannot exhaust memory or disk.
class BackupLimits {
  final int maxArchiveBytes;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxEntries;

  const BackupLimits({
    required this.maxArchiveBytes,
    required this.maxEntryBytes,
    required this.maxTotalBytes,
    required this.maxEntries,
  });

  static const standard = BackupLimits(
    maxArchiveBytes: 512 * 1024 * 1024,
    maxEntryBytes: 512 * 1024 * 1024,
    maxTotalBytes: 1024 * 1024 * 1024,
    maxEntries: 20000,
  );
}

class BackupService {
  final ObjectBoxService _objectBoxService;
  final SharedPreferences _prefs;
  final NotificationService _notificationService;
  final SupabaseClient? _supabaseClient;
  final BackupLimits _limits;

  BackupService(
    this._objectBoxService,
    this._prefs,
    this._notificationService, {
    SupabaseClient? supabaseClient,
    BackupLimits limits = BackupLimits.standard,
  }) : _supabaseClient = supabaseClient,
       _limits = limits;

  /// Test seam: runs after the database snapshot is taken, before zipping.
  @visibleForTesting
  Future<void> Function(Directory snapshotDbDir)? debugAfterSnapshot;

  /// Test seam: runs while the restore holds the store, after it is closed.
  @visibleForTesting
  Future<void> Function()? debugDuringSwap;

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

      if (!await dbDir.exists()) return false;

      final zipPath = await _getAutoBackupZipPath();
      final tmpZip = await _createBackupZip('$zipPath.tmp');
      if (tmpZip == null) return false;
      await _replaceWithRotation(tmpZip, zipPath);

      await _prefs.setString(_lastBackupKey, todayStr);
      AppLogger.instance.info(
        'Auto backup successful for $todayStr → $zipPath',
      );

      // * Cloud Upload to Supabase Storage
      try {
        final client = _supabaseClient;
        final user = client?.auth.currentUser;
        if (client != null && user != null) {
          final file = File(zipPath);
          final bytes = await file.readAsBytes();

          final cloudPath = '${user.id}/kawai_notes_backup.zip';
          await client.storage
              .from('backups')
              .uploadBinary(
                cloudPath,
                bytes,
                fileOptions: const FileOptions(upsert: true),
              );
          AppLogger.instance.info(
            'Cloud backup uploaded successfully to $cloudPath',
          );
        }
      } catch (e, stack) {
        AppLogger.instance.error('Cloud backup upload error', e, stack);
      }

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

      return await _restoreFromZip(file);
    } catch (e, stack) {
      AppLogger.instance.error('Restore from auto backup error', e, stack);
      return false;
    }
  }

  // --- Safe Restore ---

  static const String _dbDirName = 'notes_db';
  static const String _legacyNotesDirName = 'notes';
  static const String _dbDataEntry = '$_dbDirName/data.mdb';
  static const String _imagesDirName = 'images';
  static const String _bgFilePrefix = 'note_bg_';

  static final RegExp _markdownImagePath = RegExp(r'(!\[[^\]]*\]\()([^)\s]+)(\))');

  /// Decode [bytes] and return the archive only if it holds a non-empty
  /// ObjectBox database and stays within [_limits]; null for anything else
  /// (non-zip, corrupt, no db, oversized).
  Archive? _decodeBackupArchive(List<int> bytes) {
    if (bytes.length > _limits.maxArchiveBytes) {
      AppLogger.instance.warning('Backup archive exceeds size limit');
      return null;
    }
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      var entries = 0;
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        entries++;
        total += entry.size;
        if (entries > _limits.maxEntries ||
            entry.size > _limits.maxEntryBytes ||
            total > _limits.maxTotalBytes) {
          AppLogger.instance.warning('Backup archive exceeds entry limits');
          return null;
        }
      }
      final db = archive.findFile(_dbDataEntry);
      if (db == null || !db.isFile) return null;
      final data = _readBounded(db, _limits.maxEntryBytes);
      if (data.isEmpty) return null;
      return archive;
    } catch (e) {
      AppLogger.instance.warning('Backup archive is not a valid zip', e);
      return null;
    }
  }

  /// Inflates [entry] but aborts once more than [limit] bytes come out, so
  /// a forged size header cannot bypass the declared-size checks.
  Uint8List _readBounded(ArchiveFile entry, int limit) {
    final out = _BoundedOutputStream(limit);
    entry.writeContent(out, freeMemory: false);
    return out.getBytes();
  }

  /// Only known top-level backup roots are extracted; anything else
  /// (absolute paths, `..` segments, unknown files) is ignored.
  String? _safeEntryPath(String name) {
    final normalized = p.posix.normalize(name.replaceAll('\\', '/'));
    if (p.posix.isAbsolute(normalized) || normalized.startsWith('..')) {
      return null;
    }
    final parts = p.posix.split(normalized);
    final root = parts.first;
    if (root == _dbDirName ||
        root == _legacyNotesDirName ||
        root == _imagesDirName) {
      return normalized;
    }
    if (parts.length == 1 && root.startsWith(_bgFilePrefix)) {
      return normalized;
    }
    return null;
  }

  Future<void> _extractTo(Archive archive, Directory target) async {
    var remaining = _limits.maxTotalBytes;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final rel = _safeEntryPath(entry.name);
      if (rel == null) continue;
      final limit = remaining < _limits.maxEntryBytes
          ? remaining
          : _limits.maxEntryBytes;
      final data = _readBounded(entry, limit);
      remaining -= data.length;
      final out = File(p.joinAll([target.path, ...p.posix.split(rel)]));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(data, flush: true);
    }
  }

  /// Validates [zipFile] in a staging directory, then swaps it in for the
  /// live store with rollback. The live data is untouched unless the
  /// archive holds a database that ObjectBox can actually open.
  Future<bool> _restoreFromZip(File zipFile) async {
    if (await zipFile.length() > _limits.maxArchiveBytes) {
      AppLogger.instance.warning('Backup archive exceeds size limit');
      return false;
    }
    final archive = _decodeBackupArchive(await zipFile.readAsBytes());
    if (archive == null) return false;

    final docsDir = await _getDocsDir();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staging = Directory(p.join(docsDir.path, '.restore_tmp_$stamp'));

    try {
      await _extractTo(archive, staging);

      // * Probe-open the staged database before touching the live one
      final stagedDb = Directory(p.join(staging.path, _dbDirName));
      final probe = await openStore(directory: stagedDb.path);
      probe.close();

      return await _objectBoxService.runExclusive(() async {
        final ok = await _swapInStagedData(docsDir, staging, stamp);
        if (ok) {
          await _mergeStagedMedia(docsDir, staging);
          _rebaseMediaPaths(docsDir.path);
        }
        return ok;
      });
    } catch (e, stack) {
      AppLogger.instance.error('Backup archive validation failed', e, stack);
      return false;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<bool> _swapInStagedData(
    Directory docsDir,
    Directory staging,
    int stamp,
  ) async {
    final roots = <String>[_dbDirName, _legacyNotesDirName];
    final moved = <String, Directory?>{};

    _objectBoxService.closeStore();
    try {
      await debugDuringSwap?.call();
      for (final root in roots) {
        final stagedDir = Directory(p.join(staging.path, root));
        if (!await stagedDir.exists()) continue;
        final liveDir = Directory(p.join(docsDir.path, root));
        Directory? backupDir;
        if (await liveDir.exists()) {
          backupDir = await liveDir.rename(
            p.join(docsDir.path, '$root.bak_$stamp'),
          );
        }
        moved[root] = backupDir;
        await stagedDir.rename(liveDir.path);
      }

      await _objectBoxService.restartStore();
    } catch (e, stack) {
      AppLogger.instance.error('Restore swap failed, rolling back', e, stack);
      await _rollback(docsDir, moved);
      return false;
    }

    for (final backupDir in moved.values) {
      if (backupDir != null && await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
    }
    return true;
  }

  /// Media is merged additively (file names carry timestamps), so restoring
  /// never deletes images that exist only on this device.
  Future<void> _mergeStagedMedia(Directory docsDir, Directory staging) async {
    try {
      final stagedImages = Directory(p.join(staging.path, _imagesDirName));
      if (await stagedImages.exists()) {
        await for (final entity in stagedImages.list(recursive: true)) {
          if (entity is! File) continue;
          final rel = p.relative(entity.path, from: stagedImages.path);
          final dest = File(p.join(docsDir.path, _imagesDirName, rel));
          if (await dest.exists()) continue;
          await dest.parent.create(recursive: true);
          await entity.copy(dest.path);
        }
      }
      await for (final entity in staging.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith(_bgFilePrefix)) continue;
        final dest = File(p.join(docsDir.path, name));
        if (!await dest.exists()) await entity.copy(dest.path);
      }
    } catch (e, stack) {
      AppLogger.instance.error('Restoring backup media failed', e, stack);
    }
  }

  /// Notes store absolute media paths; rewrite them to this device's docs
  /// dir so backups from another device/install still show their media.
  /// Hidden notes keep their ciphertext untouched.
  void _rebaseMediaPaths(String docsPath) {
    try {
      final box = _objectBoxService.exclusiveStore.box<Note>();
      final changed = <Note>[];
      for (final note in box.getAll()) {
        var dirty = false;
        final content = note.content;
        if (!note.isHidden && content != null && content.isNotEmpty) {
          final rebased = content.replaceAllMapped(_markdownImagePath, (m) {
            final target = _rebasedImagePath(m.group(2)!, docsPath);
            return '${m.group(1)}${target ?? m.group(2)}${m.group(3)}';
          });
          if (rebased != content) {
            note.content = rebased;
            dirty = true;
          }
        }
        final bg = note.customBackgroundImage;
        if (bg != null && p.basename(bg).startsWith(_bgFilePrefix)) {
          final target = p.join(docsPath, p.basename(bg));
          if (target != bg) {
            note.customBackgroundImage = target;
            dirty = true;
          }
        }
        if (dirty) changed.add(note);
      }
      if (changed.isNotEmpty) box.putMany(changed);
    } catch (e, stack) {
      AppLogger.instance.error('Rebasing media paths failed', e, stack);
    }
  }

  String? _rebasedImagePath(String original, String docsPath) {
    final parts = original.split(RegExp(r'[\\/]'));
    final idx = parts.lastIndexOf(_imagesDirName);
    if (idx < 0 || idx == parts.length - 1) return null;
    return p.joinAll([docsPath, _imagesDirName, ...parts.sublist(idx + 1)]);
  }

  Future<void> _rollback(
    Directory docsDir,
    Map<String, Directory?> moved,
  ) async {
    try {
      _objectBoxService.closeStore();
    } catch (_) {}
    for (final entry in moved.entries) {
      final liveDir = Directory(p.join(docsDir.path, entry.key));
      final backupDir = entry.value;
      try {
        if (await liveDir.exists()) await liveDir.delete(recursive: true);
        if (backupDir != null && await backupDir.exists()) {
          await backupDir.rename(liveDir.path);
        }
      } catch (e, stack) {
        AppLogger.instance.error('Rollback of ${entry.key} failed', e, stack);
      }
    }
    await _objectBoxService.restartStore();
  }

  // --- Cloud Backup Utils ---

  Future<bool> hasCloudBackup() async {
    try {
      final client = _supabaseClient;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return false;

      final cloudPath = '${user.id}/';
      final list = await client.storage.from('backups').list(path: cloudPath);
      return list.any((item) => item.name == 'kawai_notes_backup.zip');
    } catch (e) {
      return false;
    }
  }

  Future<bool> downloadRestoreCloudBackup() async {
    try {
      final client = _supabaseClient;
      final user = client?.auth.currentUser;
      if (client == null || user == null) return false;

      final cloudPath = '${user.id}/kawai_notes_backup.zip';
      final bytes = await client.storage.from('backups').download(cloudPath);

      return await restoreFromDownloadedBytes(bytes);
    } catch (e, stack) {
      AppLogger.instance.error(
        'Download & Restore cloud backup error',
        e,
        stack,
      );
      return false;
    }
  }

  /// Restores from downloaded backup bytes. The bytes are staged in a temp
  /// file and the local auto-backup zip is only replaced after a
  /// successful restore, so a bad download never destroys it.
  @visibleForTesting
  Future<bool> restoreFromDownloadedBytes(Uint8List bytes) async {
    if (_decodeBackupArchive(bytes) == null) return false;

    final zipPath = await _getAutoBackupZipPath();
    final tmp = File('$zipPath.download');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      final ok = await _restoreFromZip(tmp);
      if (ok) {
        await _replaceWithRotation(tmp, zipPath);
      }
      return ok;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// Moves [source] to [targetPath], keeping the previous file as `.prev`.
  Future<void> _replaceWithRotation(File source, String targetPath) async {
    final target = File(targetPath);
    if (await target.exists()) {
      await target.rename('$targetPath.prev');
    }
    await source.rename(targetPath);
  }

  /// Writes a backup zip to [zipPath] and returns it only if it decodes
  /// back into a valid backup; a failed or invalid zip is deleted.
  ///
  /// The database is copied while a read transaction pins a consistent
  /// LMDB snapshot, and that copy must open in ObjectBox before it is zipped.
  Future<File?> _createBackupZip(String zipPath) async {
    final docsDir = await _getDocsDir();
    final notesDir = Directory(p.join(docsDir.path, _legacyNotesDirName));
    final zipFile = File(zipPath);
    final work = Directory(
      p.join(docsDir.path, '.backup_${DateTime.now().microsecondsSinceEpoch}'),
    );

    try {
      final snapshotDb = Directory(p.join(work.path, _dbDirName));
      _snapshotDatabase(docsDir, snapshotDb);
      await debugAfterSnapshot?.call(snapshotDb);
      await _probeOpenCopy(snapshotDb, Directory(p.join(work.path, 'probe')));

      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addDirectory(snapshotDb);
      if (await notesDir.exists()) {
        await encoder.addDirectory(notesDir);
      }
      final imagesDir = Directory(p.join(docsDir.path, _imagesDirName));
      if (await imagesDir.exists()) {
        await encoder.addDirectory(imagesDir);
      }
      await for (final entity in docsDir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith(_bgFilePrefix)) {
          await encoder.addFile(entity, p.basename(entity.path));
        }
      }
      await encoder.close();

      if (_decodeBackupArchive(await zipFile.readAsBytes()) == null) {
        AppLogger.instance.error('Created backup zip failed validation');
        await zipFile.delete();
        return null;
      }
      return zipFile;
    } catch (e, stack) {
      AppLogger.instance.error('Creating backup zip failed', e, stack);
      if (await zipFile.exists()) await zipFile.delete();
      return null;
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  /// Copies `data.mdb` inside a read transaction. LMDB never reuses pages
  /// visible to an open reader, so the copy is a consistent snapshot even
  /// while other code keeps writing. `lock.mdb` is runtime state and is
  /// never backed up.
  void _snapshotDatabase(Directory docsDir, Directory target) {
    final live = File(p.join(docsDir.path, _dbDirName, 'data.mdb'));
    target.createSync(recursive: true);
    _objectBoxService.store.runInTransaction(TxMode.read, () {
      live.copySync(p.join(target.path, 'data.mdb'));
    });
  }

  /// Opens a throwaway copy of [snapshotDb] so the zipped bytes are exactly
  /// what was validated (opening may write a lock file).
  Future<void> _probeOpenCopy(Directory snapshotDb, Directory probeDir) async {
    probeDir.createSync(recursive: true);
    File(
      p.join(snapshotDb.path, 'data.mdb'),
    ).copySync(p.join(probeDir.path, 'data.mdb'));
    final probe = await openStore(directory: probeDir.path);
    probe.close();
  }

  // --- Manual Backup ---

  Future<bool> exportBackupManual() async {
    File? tempFile;
    try {
      final docsDir = await _getDocsDir();
      tempFile = await _createBackupZip(
        p.join(docsDir.path, 'temp_export.zip'),
      );
      if (tempFile == null) return false;

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'kawai_notes_backup_$dateStr.zip';

      // * file_picker writes the bytes itself (required on Android/iOS)
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: await tempFile.readAsBytes(),
      );

      return outputPath != null;
    } catch (e, stack) {
      AppLogger.instance.error('Backup export error', e, stack);
      return false;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<bool> importBackupManual() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      final pickedPath = result?.files.single.path;
      if (pickedPath == null) return false;

      return await _restoreFromZip(File(pickedPath));
    } catch (e, stack) {
      AppLogger.instance.error('Backup import error', e, stack);
      return false;
    }
  }
}

class _BoundedOutputStream extends OutputMemoryStream {
  final int limit;

  _BoundedOutputStream(this.limit);

  void _check(int extra) {
    if (length + extra > limit) {
      throw const FileSystemException('Backup entry exceeds size limit');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}
