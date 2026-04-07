import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
      return success;
    } catch (e, stack) {
      AppLogger.instance.error('Run auto backup now failed', e, stack);
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<void> setAutoBackupFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Auto Backup Folder',
    );
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
