import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine the current route to highlight the selected item
    // In GoRouter, you can sometimes get current location via GoRouterState
    // But since this is a simple app, we can just rely on the navigator
    // or let it be stateless visually if we aren't tracking route state.

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: context.colorScheme.primary),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    color: context.colorScheme.onPrimary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Kawai Notes',
                    customStyle: TextStyle(
                      color: context.colorScheme.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.note_outlined),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              context.replace('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_box_outlined),
            title: const Text('Tasks'),
            onTap: () {
              Navigator.pop(context);
              context.replace('/tasks');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.replace('/other');
            },
          ),
        ],
      ),
    );
  }
}
