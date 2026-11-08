import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/core/utils/toast_utils.dart';
import 'package:kawai_notes/feature/auth/providers/auth_provider.dart';
import 'package:kawai_notes/feature/notes/widgets/hidden_notes_auth_body.dart';
import 'package:kawai_notes/feature/other/providers/backup_provider.dart';
import 'package:kawai_notes/shared/widgets/app_button.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDateAsync = ref.watch(backupAutoDateProvider);
    final backupState = ref.watch(backupProvider);
    final folderAsync = ref.watch(autoBackupFolderProvider);
    final timeAsync = ref.watch(autoBackupTimeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final cloudExistsAsync = ref.watch(cloudBackupExistsProvider);

    return Scaffold(
      appBar: AppBar(title: AppText(context.l10n.settingsBackupAndRestore)),
      body: ScreenWrapper(
        child: backupState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Manual Backup ───────────────────────────────
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
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.success(context.l10n.settingsBackupExportSuccess);
                      } else {
                        AppToast.error(context.l10n.settingsBackupExportFailed);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),

                  // ─── Restore Backup ──────────────────────────────
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
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.success(context.l10n.settingsRestoreSuccess);
                        Phoenix.rebirth(context);
                      } else {
                        AppToast.error(context.l10n.settingsRestoreFailed);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),

                  // ─── Cloud Backup ────────────────────────────────
                  if (currentUser != null) ...[
                    AppText(
                      context.l10n.settingsCloudBackupTitle,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    const SizedBox(height: 8),
                    AppText(context.l10n.settingsCloudBackupDescription),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: context.l10n.settingsCloudUpload,
                            onPressed: () async {
                              final success = await ref
                                  .read(backupProvider.notifier)
                                  .runAutoBackupNow();
                              if (!context.mounted) return;
                              if (success) {
                                AppToast.success(context.l10n.settingsCloudUploadSuccess);
                              } else {
                                AppToast.error(context.l10n.settingsCloudUploadFailed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: cloudExistsAsync.when(
                            data: (exists) => AppButton(
                              text: context.l10n.settingsCloudRestore,
                              onPressed: exists
                                  ? () async {
                                      final confirm = await _showConfirmDialog(
                                        context,
                                      );
                                      if (confirm != true) return;

                                      final success = await ref
                                          .read(backupProvider.notifier)
                                          .restoreCloudBackup();
                                      if (!context.mounted) return;
                                      if (success) {
                                        AppToast.success(
                                          context.l10n.settingsRestoreSuccess,
                                        );
                                        Phoenix.rebirth(context);
                                      } else {
                                        AppToast.error(
                                          context.l10n.settingsRestoreFailed,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => AppButton(
                              text: context.l10n.settingsCloudError,
                              onPressed: null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                  ] else ...[
                    AppText(
                      context.l10n.settingsCloudBackupTitle,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      context.l10n.settingsCloudLoginRequired,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                  ],

                  // ─── Auto Backup ─────────────────────────────────
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
                    error: (e, _) =>
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
                            if (!context.mounted) return;
                            if (success) {
                              AppToast.success(context.l10n.settingsRestoreSuccess);
                              Phoenix.rebirth(context);
                            } else {
                              AppToast.error(context.l10n.settingsRestoreFailed);
                            }
                          },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),

                  // ─── Hidden Notes Key ────────────────────────────
                  const AppText(
                    'Hidden Notes Key',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Backups never contain the hidden notes key. To read '
                    'hidden notes on another device, export the key with a '
                    'passphrase and import it there before restoring.',
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    key: const Key('export_hidden_key'),
                    text: 'Export Hidden Notes Key',
                    onPressed: () => _exportKey(context, ref),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    key: const Key('import_hidden_key'),
                    text: 'Import Hidden Notes Key',
                    onPressed: () => _importKey(context, ref),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),

                  // ─── Auto Backup Settings ─────────────────────────
                  AppText(
                    context.l10n.settingsAutoBackupSettings,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 16),

                  // * Folder tujuan
                  _buildSettingsRow(
                    context: context,
                    label: context.l10n.settingsAutoBackupFolder,
                    value: folderAsync.when(
                      data: (folder) =>
                          folder ??
                          context.l10n.settingsAutoBackupFolderDefault,
                      loading: () => '...',
                      error: (e, _) => '-',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => ref
                            .read(backupProvider.notifier)
                            .setAutoBackupFolder(),
                        child: AppText(
                          context.l10n.settingsAutoBackupChooseFolder,
                          color: context.colorScheme.primary,
                        ),
                      ),
                      if (folderAsync.value != null)
                        TextButton(
                          onPressed: () => ref
                              .read(backupProvider.notifier)
                              .clearAutoBackupFolder(),
                          child: AppText(
                            context.l10n.settingsAutoBackupResetFolder,
                            color: context.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // * Waktu backup
                  _buildSettingsRow(
                    context: context,
                    label: context.l10n.settingsAutoBackupTime,
                    value: timeAsync.when(
                      data: (time) =>
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      loading: () => '...',
                      error: (e, _) => '-',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          final current = timeAsync.value;
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                current ?? const TimeOfDay(hour: 2, minute: 0),
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (picked != null && context.mounted) {
                            await ref
                                .read(backupProvider.notifier)
                                .setAutoBackupTime(picked.hour, picked.minute);
                          }
                        },
                        child: AppText(
                          context.l10n.settingsAutoBackupSetTime,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // * Tombol run now
                  AppButton(
                    text: context.l10n.settingsAutoBackupRunNow,
                    onPressed: () async {
                      final success = await ref
                          .read(backupProvider.notifier)
                          .runAutoBackupNow();
                      if (!context.mounted) return;
                      if (success) {
                        AppToast.success(context.l10n.settingsAutoBackupRunSuccess);
                      } else {
                        AppToast.error(context.l10n.settingsAutoBackupRunFailed);
                      }
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required BuildContext context,
    required String label,
    required String value,
    required List<Widget> actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, fontWeight: FontWeight.w500),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: AppText(
                value,
                fontSize: 13,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }

  Future<void> _exportKey(BuildContext context, WidgetRef ref) async {
    // * exporting the key requires the hidden-notes credential
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: HiddenNotesAuthBody(
          onSuccess: () => Navigator.of(sheetCtx).pop(true),
          onCancel: () => Navigator.of(sheetCtx).pop(false),
        ),
      ),
    );
    if (verified != true || !context.mounted) return;
    final passphrase = await _askPassphrase(context, confirm: true);
    if (passphrase == null) return;
    final ok = await ref
        .read(backupProvider.notifier)
        .exportEncryptionKey(passphrase);
    if (ok) {
      AppToast.success('Hidden notes key exported');
    } else {
      AppToast.error('Key export failed');
    }
  }

  Future<void> _importKey(BuildContext context, WidgetRef ref) async {
    final passphrase = await _askPassphrase(context, confirm: false);
    if (passphrase == null) return;
    final ok = await ref
        .read(backupProvider.notifier)
        .importEncryptionKey(passphrase);
    if (ok) {
      AppToast.success('Hidden notes key imported');
    } else {
      AppToast.error(
        'Key import failed: wrong passphrase or invalid key file',
      );
    }
  }

  Future<String?> _askPassphrase(
    BuildContext context, {
    required bool confirm,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _PassphraseDialog(confirm: confirm),
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

class _PassphraseDialog extends StatefulWidget {
  final bool confirm;

  const _PassphraseDialog({required this.confirm});

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  static const _minLength = 8;
  final _pass = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final pass = _pass.text;
    if (widget.confirm && pass.length < _minLength) {
      setState(() => _error = 'Use at least $_minLength characters');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Passphrase cannot be empty');
      return;
    }
    if (widget.confirm && pass != _again.text) {
      setState(() => _error = "Passphrases don't match");
      return;
    }
    Navigator.pop(context, pass);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText('Key passphrase'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('key_passphrase'),
            controller: _pass,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              errorText: widget.confirm ? null : _error,
            ),
          ),
          if (widget.confirm)
            TextField(
              key: const Key('key_passphrase_confirm'),
              controller: _again,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm passphrase',
                errorText: _error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: AppText(context.l10n.settingsCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: AppText(context.l10n.settingsContinue),
        ),
      ],
    );
  }
}
