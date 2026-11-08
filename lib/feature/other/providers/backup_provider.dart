import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/services/backup_service.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/di/service_providers.dart';

final backupAutoDateProvider = FutureProvider.autoDispose<DateTime?>((
  ref,
) async {
  final backupService = ref.watch(backupServiceProvider);
  return await backupService.getAutoBackupDate();
});

final autoBackupFolderProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.getAutoBackupFolder();
});

final autoBackupTimeProvider = FutureProvider.autoDispose<TimeOfDay>((
  ref,
) async {
  final backupService = ref.watch(backupServiceProvider);
  return backupService.getAutoBackupTime();
});

final cloudBackupExistsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final backupService = ref.watch(backupServiceProvider);
  return await backupService.hasCloudBackup();
});

class BackupNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  BackupService get _backupService => ref.read(backupServiceProvider);

  Future<bool> exportBackup() async {
    state = const AsyncLoading();
    try {
      final success = await _backupService.exportBackupManual();
      state = const AsyncData(null);
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Backup export failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> importBackup() async {
    state = const AsyncLoading();
    try {
      final success = await _backupService.importBackupManual();
      state = const AsyncData(null);
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Backup import failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> restoreAutoBackup() async {
    state = const AsyncLoading();
    try {
      final success = await _backupService.restoreFromAutoBackup();
      state = const AsyncData(null);
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Restore auto backup failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> runAutoBackupNow() async {
    state = const AsyncLoading();
    try {
      final success = await _backupService.runAutoBackup(forceRun: true);
      state = const AsyncData(null);
      ref.invalidate(backupAutoDateProvider);
      ref.invalidate(cloudBackupExistsProvider);
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Run auto backup now failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> restoreCloudBackup() async {
    state = const AsyncLoading();
    try {
      final success = await _backupService.downloadRestoreCloudBackup();
      state = const AsyncData(null);
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Restore cloud backup failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  /// Saves the hidden-notes key, wrapped with [passphrase], to a file the
  /// user picks. Backups never contain the key itself.
  Future<bool> exportEncryptionKey(String passphrase) async {
    try {
      final wrapped = await ref
          .read(encryptionServiceProvider)
          .exportWrappedKey(passphrase);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Hidden Notes Key',
        fileName: 'kawai_notes_hidden_key.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(wrapped)),
      );
      return path != null;
    } catch (e, stack) {
      AppLogger.instance.error('Key export failed', e, stack);
      return false;
    }
  }

  /// Installs a key file created by [exportEncryptionKey]. Fails closed:
  /// a wrong passphrase or invalid file stores nothing, and existing keys
  /// are always kept alongside the imported ones.
  Future<bool> importEncryptionKey(String passphrase) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return false;
      await ref
          .read(encryptionServiceProvider)
          .importWrappedKey(await File(path).readAsString(), passphrase);
      return true;
    } catch (e, stack) {
      AppLogger.instance.error('Key import failed', e, stack);
      return false;
    }
  }

  Future<void> setAutoBackupFolder() async {
    String? path;
    try {
      path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Auto Backup Folder',
      );
    } on PlatformException catch (e, stack) {
      AppLogger.instance.error('FilePicker platform error', e, stack);
      return;
    }
    if (path != null) {
      await _backupService.setAutoBackupFolder(path);
      ref.invalidate(autoBackupFolderProvider);
    }
  }

  Future<void> clearAutoBackupFolder() async {
    await _backupService.setAutoBackupFolder(null);
    ref.invalidate(autoBackupFolderProvider);
  }

  Future<void> setAutoBackupTime(int hour, int minute) async {
    await _backupService.setAutoBackupTime(hour, minute);
    ref.invalidate(autoBackupTimeProvider);
  }
}

final backupProvider = AsyncNotifierProvider.autoDispose<BackupNotifier, void>(
  BackupNotifier.new,
);
