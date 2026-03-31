import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/di/common_providers.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: ScreenWrapper(
        child: ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              title: const Text('Use Material You'),
              subtitle: const Text('Follow system dynamic colors'),
              value: isMaterialYouEnabled,
              onChanged: (bool value) {
                ref.read(materialYouProvider.notifier).toggle();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                onChanged: (ThemeMode? newTheme) {
                  if (newTheme != null) {
                    ref.read(themeProvider.notifier).changeTheme(newTheme);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: locale.languageCode,
                onChanged: (String? newLang) {
                  if (newLang != null) {
                    ref
                        .read(localeProvider.notifier)
                        .changeLocale(Locale(newLang));
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
