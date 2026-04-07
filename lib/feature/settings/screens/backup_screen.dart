import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/feature/settings/providers/backup_provider.dart';
import 'package:kawai_notes/shared/widgets/app_button.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';
import 'package:intl/intl.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDateAsync = ref.watch(backupAutoDateProvider);
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      appBar: AppBar(title: AppText(context.l10n.settingsBackupAndRestore)),
      body: ScreenWrapper(
        child: backupState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppText(
                    context.l10n.settingsManualBackup,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  AppText(context.l10n.settingsExportYourNotesToAZipFile),
                  const SizedBox(height: 16),
                  AppButton(
                    text: context.l10n.settingsExportBackup,
                    onPressed: () async {
                      final success = await ref
                          .read(backupProvider.notifier)
                          .exportBackup();
                      if (success) {
                        BotToast.showText(
                          text: context.l10n.settingsBackupExportSuccess,
                        );
                      } else {
                        BotToast.showText(
                          text: context.l10n.settingsBackupExportFailed,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  AppText(
                    context.l10n.settingsRestoreBackupTitle,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  AppText(context.l10n.settingsRestoreDescription),
                  const SizedBox(height: 16),
                  AppButton(
                    text: context.l10n.settingsImportBackupBtn,
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(context);
                      if (confirm != true) return;

                      final success = await ref
                          .read(backupProvider.notifier)
                          .importBackup();
                      if (success) {
                        BotToast.showText(
                          text: context.l10n.settingsRestoreSuccess,
                        );
                        if (context.mounted) {
                          Phoenix.rebirth(context);
                        }
                      } else {
                        BotToast.showText(
                          text: context.l10n.settingsRestoreFailed,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  AppText(
                    context.l10n.settingsAutoBackupTitle,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  autoDateAsync.when(
                    data: (date) => AppText(
                      date != null
                          ? context.l10n.settingsLastAutoBackup(
                              DateFormat('yyyy-MM-dd HH:mm').format(date),
                            )
                          : context.l10n.settingsNoAutoBackup,
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) =>
                        AppText(context.l10n.settingsErrorLoadingAutoBackup),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: context.l10n.settingsRestoreFromAutoBackup,
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
                                text: context.l10n.settingsRestoreSuccess,
                              );
                              if (context.mounted) {
                                Phoenix.rebirth(context);
                              }
                            } else {
                              BotToast.showText(
                                text: context.l10n.settingsRestoreFailed,
                              );
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
        title: AppText(context.l10n.settingsAreYouSure),
        content: AppText(context.l10n.settingsOverwriteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: AppText(context.l10n.settingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: AppText(context.l10n.settingsContinue),
          ),
        ],
      ),
    );
  }
}
