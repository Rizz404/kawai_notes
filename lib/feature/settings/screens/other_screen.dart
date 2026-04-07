import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/feature/notes/providers/xiaomi_import_provider.dart';
import 'package:kawai_notes/shared/widgets/app_drawer.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

class OtherScreen extends ConsumerWidget {
  const OtherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isMaterialYouEnabled = ref.watch(materialYouProvider);

    return Scaffold(
      appBar: AppBar(title: AppText(context.l10n.settingsTitle)),
      drawer: const AppDrawer(),
      body: ScreenWrapper(
        child: ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              title: AppText(context.l10n.settingsMaterialYou),
              subtitle: AppText(context.l10n.settingsMaterialYouSubtitle),
              value: isMaterialYouEnabled,
              onChanged: (bool value) {
                ref.read(materialYouProvider.notifier).toggle();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: AppText(context.l10n.settingsTheme),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (ThemeMode? newTheme) {
                  if (newTheme != null) {
                    ref.read(themeProvider.notifier).changeTheme(newTheme);
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: AppText(context.l10n.settingsThemeSystem),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: AppText(context.l10n.settingsThemeLight),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: AppText(context.l10n.settingsThemeDark),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: AppText(context.l10n.settingsLanguage),
              trailing: DropdownButton<String>(
                value: locale.languageCode,
                onChanged: (String? newLang) {
                  if (newLang != null) {
                    ref
                        .read(localeProvider.notifier)
                        .changeLocale(Locale(newLang));
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: AppText(context.l10n.settingsLanguageEnglish),
                  ),
                  DropdownMenuItem(
                    value: 'ja',
                    child: AppText(context.l10n.settingsLanguageJapanese),
                  ),
                  DropdownMenuItem(
                    value: 'id',
                    child: AppText(context.l10n.settingsLanguageIndonesian),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: AppText(context.l10n.settingsBackupAndRestore),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/backup');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outlined),
              title: AppText(context.l10n.settingsTrash),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/trash');
              },
            ),
            const Divider(),
            Consumer(
              builder: (context, ref, child) {
                final importState = ref.watch(xiaomiImportProvider);
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.note_add_outlined),
                      title: AppText(
                        context.l10n.settingsImportXiaomiNotesBulk,
                      ),
                      trailing:
                          importState.isMutating &&
                              !importState.isImportingFolder
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (importState.isMutating) return;
                        final didImport = await ref
                            .read(xiaomiImportProvider.notifier)
                            .importXiaomiNotesBulk();
                        if (context.mounted) {
                          final error = ref
                              .read(xiaomiImportProvider)
                              .mutationError;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  context.l10n.settingsImportFailed(
                                    error.toString(),
                                  ),
                                ),
                              ),
                            );
                          } else if (didImport) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  context.l10n.settingsImportSuccessful,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.folder_shared_outlined),
                      title: AppText(
                        context.l10n.settingsImportXiaomiNotesFolder,
                      ),
                      subtitle: importState.isImportingFolder
                          ? AppText(
                              context.l10n.settingsImportFolderProgress(
                                importState.processedFiles,
                                importState.totalFiles,
                              ),
                            )
                          : null,
                      trailing: importState.isImportingFolder
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (importState.isMutating) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: AppText(
                                context.l10n.settingsImportAnotherRunning,
                              ),
                            ),
                          );
                          return;
                        }

                        final didImport = await ref
                            .read(xiaomiImportProvider.notifier)
                            .importXiaomiNotesFromFolder(
                              importingNotesTitle:
                                  context.l10n.notesImportingNotes,
                            );

                        if (context.mounted) {
                          final error = ref
                              .read(xiaomiImportProvider)
                              .mutationError;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  context.l10n.settingsFolderImportFailed(
                                    error.toString(),
                                  ),
                                ),
                              ),
                            );
                          } else if (didImport) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: AppText(
                                  context.l10n.settingsImportSuccessful,
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
