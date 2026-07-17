import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/backup_service.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/other/providers/backup_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockBackupService extends Mock implements BackupService {}

void main() {
  late MockBackupService backupService;
  late ProviderContainer container;

  setUp(() {
    backupService = MockBackupService();
    container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(backupService)],
    );
  });

  tearDown(() => container.dispose());

  test('exportBackup returns true and settles to AsyncData on success', () async {
    when(() => backupService.exportBackupManual()).thenAnswer((_) async => true);

    final result = await container
        .read(backupProvider.notifier)
        .exportBackup();

    expect(result, isTrue);
    expect(container.read(backupProvider), const AsyncData<void>(null));
  });

  test('exportBackup returns false and captures the error on failure', () async {
    final error = Exception('disk full');
    when(() => backupService.exportBackupManual()).thenThrow(error);

    final result = await container
        .read(backupProvider.notifier)
        .exportBackup();

    expect(result, isFalse);
    expect(container.read(backupProvider).hasError, isTrue);
  });

  test('importBackup delegates to BackupService.importBackupManual', () async {
    when(() => backupService.importBackupManual()).thenAnswer((_) async => true);

    final result = await container
        .read(backupProvider.notifier)
        .importBackup();

    expect(result, isTrue);
    verify(() => backupService.importBackupManual()).called(1);
  });

  test('runAutoBackupNow forces a run and reports failure', () async {
    when(() => backupService.runAutoBackup(forceRun: true))
        .thenAnswer((_) async => false);

    final result = await container
        .read(backupProvider.notifier)
        .runAutoBackupNow();

    expect(result, isFalse);
    verify(() => backupService.runAutoBackup(forceRun: true)).called(1);
  });

  test('restoreCloudBackup delegates to BackupService.downloadRestoreCloudBackup', () async {
    when(() => backupService.downloadRestoreCloudBackup())
        .thenAnswer((_) async => true);

    final result = await container
        .read(backupProvider.notifier)
        .restoreCloudBackup();

    expect(result, isTrue);
  });

  test('clearAutoBackupFolder clears the folder via setAutoBackupFolder(null)', () async {
    when(() => backupService.setAutoBackupFolder(null)).thenAnswer((_) async {});

    await container.read(backupProvider.notifier).clearAutoBackupFolder();

    verify(() => backupService.setAutoBackupFolder(null)).called(1);
  });

  test('setAutoBackupTime forwards hour/minute to BackupService', () async {
    when(() => backupService.setAutoBackupTime(any(), any())).thenAnswer((_) async {});

    await container.read(backupProvider.notifier).setAutoBackupTime(7, 30);

    verify(() => backupService.setAutoBackupTime(7, 30)).called(1);
  });
}
