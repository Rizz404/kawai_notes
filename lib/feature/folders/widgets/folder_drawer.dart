import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/feature/folders/providers/folder_list_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

class FolderDrawer extends ConsumerWidget {
  const FolderDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderStateAsync = ref.watch(folderListNotifierProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: AppText(
                'Folders',
                style: AppTextStyle.headlineSmall,
                color: context.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.note_outlined),
            title: const AppText('All Notes'),
            onTap: () {
              // TODO: filter to all notes
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_shared_outlined),
            title: const AppText('Uncategorized'),
            onTap: () {
              // TODO: filter uncategorized
              Navigator.pop(context);
            },
          ),
          const Divider(),
          Expanded(
            child: folderStateAsync.when(
              data: (state) {
                final folders = state.items;
                if (folders.isEmpty) {
                  return const Center(child: AppText('No custom folders'));
                }
                return ListView.builder(
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: AppText(folder.name),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: context.colorScheme.error),
                        onPressed: () {
                          ref
                              .read(folderListNotifierProvider.notifier)
                              .deleteFolder(folder.id);
                        },
                      ),
                      onTap: () {
                        // TODO: filter by this folder
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: AppText('Error: $e')),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const AppText('Create New Folder'),
            onTap: () {
              // Show dialog to create folder
              _showCreateFolderDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const AppText('New Folder'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Folder name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref.read(folderListNotifierProvider.notifier).createFolder(name);
                }
                Navigator.pop(context);
              },
              child: const AppText('Create'),
            ),
          ],
        );
      },
    );
  }
}
