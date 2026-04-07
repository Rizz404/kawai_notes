import 'package:flutter/material.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/feature/settings/providers/trash_provider.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(trashListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppText(context.l10n.settingsTrash),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: AppText(context.l10n.settingsEmptyTrashQuestion),
                    content: AppText(
                      context.l10n.settingsTrashDeleteDescription,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: AppText(context.l10n.settingsCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: context.colorScheme.error,
                        ),
                        child: AppText(context.l10n.settingsDelete),
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
              return Center(child: AppText(context.l10n.settingsTrashIsEmpty));
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
                    ? context.l10n.settingsTrashDeleteSubtitleReady(daysLeft)
                    : context.l10n.settingsTrashDeleteSubtitleSoon;

                return ListTile(
                  title: AppText(
                    note.title.isEmpty
                        ? context.l10n.settingsUntitled
                        : note.title,
                  ),
                  subtitle: AppText(subtitleText),
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
                        child: AppText(context.l10n.settingsRestore),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: AppText(context.l10n.settingsDeletePermanently),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: AppText(err.toString())),
        ),
      ),
    );
  }
}
