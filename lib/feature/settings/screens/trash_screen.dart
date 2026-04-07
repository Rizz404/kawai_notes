import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/feature/settings/providers/trash_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(trashListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTrash),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Empty Trash?'),
                    content: const Text(
                      'All notes in the trash will be permanently deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.settingsCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colorScheme.error,
                        ),
                        child: Text(context.l10n.settingsDelete),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                await ref.read(trashListNotifierProvider.notifier).emptyTrash();
              }
            },
          ),
        ],
      ),
      body: ScreenWrapper(
        child: stateAsync.when(
          data: (notes) {
            if (notes.isEmpty) {
              return const Center(child: Text('Trash is empty.'));
            }

            return ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final note = notes[index];
                final expirationDate = note.updatedAt.add(
                  const Duration(days: 30),
                );
                final daysLeft = expirationDate
                    .difference(DateTime.now())
                    .inDays;
                final subtitleText = daysLeft > 0
                    ? 'Deleted (auto-delete in $daysLeft days)'
                    : 'Deleted (auto-delete very soon)';

                return ListTile(
                  title: Text(note.title.isEmpty ? 'Untitled' : note.title),
                  subtitle: Text(subtitleText),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') {
                        ref
                            .read(trashListNotifierProvider.notifier)
                            .restoreNote(note.id);
                      } else if (value == 'delete') {
                        ref
                            .read(trashListNotifierProvider.notifier)
                            .deletePermanently(note.id);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'restore',
                        child: Text(context.l10n.settingsRestore),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(context.l10n.settingsDeletePermanently),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
        ),
      ),
    );
  }
}
