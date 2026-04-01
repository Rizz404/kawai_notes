import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/services/backup_service.dart';
import 'package:flutter_setup_riverpod/core/utils/logger.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';

final backupAutoDateProvider = FutureProvider.autoDispose<DateTime?>((
  ref,
) async {
  final backupService = ref.watch(backupServiceProvider);
  return await backupService.getAutoBackupDate();
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
}

final backupProvider = AsyncNotifierProvider.autoDispose<BackupNotifier, void>(
  BackupNotifier.new,
);
