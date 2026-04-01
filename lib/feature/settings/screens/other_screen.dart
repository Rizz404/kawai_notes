import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/di/common_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/xiaomi_import_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_drawer.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class OtherScreen extends ConsumerWidget {
  const OtherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isMaterialYouEnabled = ref.watch(materialYouProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      drawer: const AppDrawer(),
      body: ScreenWrapper(
        child: ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              title: Text(context.l10n.settingsMaterialYou),
              subtitle: Text(context.l10n.settingsMaterialYouSubtitle),
              value: isMaterialYouEnabled,
              onChanged: (bool value) {
                ref.read(materialYouProvider.notifier).toggle();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(context.l10n.settingsTheme),
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
                    child: Text(context.l10n.settingsThemeSystem),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(context.l10n.settingsThemeLight),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(context.l10n.settingsThemeDark),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(context.l10n.settingsLanguage),
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
                    child: Text(context.l10n.settingsLanguageEnglish),
                  ),
                  DropdownMenuItem(
                    value: 'ja',
                    child: Text(context.l10n.settingsLanguageJapanese),
                  ),
                  DropdownMenuItem(
                    value: 'id',
                    child: Text(context.l10n.settingsLanguageIndonesian),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & Restore'), // TODO: Localization
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/backup');
              },
            ),
            const Divider(),
            Consumer(
              builder: (context, ref, child) {
                final importState = ref.watch(xiaomiImportProvider);
                return ListTile(
                  leading: const Icon(Icons.note_add_outlined),
                  title: const Text('Import Xiaomi Notes (Bulk)'),
                  trailing: importState.isMutating
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
                          SnackBar(content: Text('Import failed: $error')),
                        );
                      } else if (didImport) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Import successful!')),
                        );
                      }
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
