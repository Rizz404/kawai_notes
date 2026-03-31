import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/feature/settings/providers/backup_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_button.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';
import 'package:intl/intl.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDateAsync = ref.watch(backupAutoDateProvider);
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ScreenWrapper(
        child: backupState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AppText(
                    'Manual Backup',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  const AppText('Export your notes to a zip file.'),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Export Backup',
                    onPressed: () async {
                      final success = await ref
                          .read(backupProvider.notifier)
                          .exportBackup();
                      if (success) {
                        BotToast.showText(text: 'Backup exported successfully');
                      } else {
                        BotToast.showText(
                          text: 'Backup export cancelled or failed',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  const AppText(
                    'Restore Backup',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Import notes from a zip file. This will replace your current data.',
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Import Backup',
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(context);
                      if (confirm != true) return;

                      final success = await ref
                          .read(backupProvider.notifier)
                          .importBackup();
                      if (success) {
                        BotToast.showText(
                          text: 'Restore successful, restarting app...',
                        );
                        if (context.mounted) {
                          Phoenix.rebirth(context);
                        }
                      } else {
                        BotToast.showText(text: 'Restore failed');
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  const AppText(
                    'Auto Backup',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  autoDateAsync.when(
                    data: (date) => AppText(
                      date != null
                          ? 'Last auto backup: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}'
                          : 'No auto backup available.',
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) =>
                        const AppText('Error loading auto backup status'),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Restore from Auto Backup',
                    onPressed: autoDateAsync.value == null
                        ? null
                        : () async {
                            final confirm = await _showConfirmDialog(context);
                            if (confirm != true) return;

                            final success = await ref
                                .read(backupProvider.notifier)
                                .restoreAutoBackup();
                            if (success) {
                              BotToast.showText(
                                text: 'Restore successful, restarting app...',
                              );
                              if (context.mounted) {
                                Phoenix.rebirth(context);
                              }
                            } else {
                              BotToast.showText(text: 'Restore failed');
                            }
                          },
                  ),
                ],
              ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'This will overwrite all your current notes. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
