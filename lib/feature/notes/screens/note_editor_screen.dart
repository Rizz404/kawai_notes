import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_providers.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_rich_text_editor.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text_field.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final int? noteId;
  final String? initialTitle;

  const NoteEditorScreen({super.key, this.noteId, this.initialTitle});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    // Watch the form state from detail provider
    final stateAsync = ref.watch(noteDetailNotifierProvider(widget.noteId));

    // Listen to mutation changes for navigation and error tracking
    ref.listen<AsyncValue<NoteDetailState>>(
      noteDetailNotifierProvider(widget.noteId),
      (previous, next) {
        if (next.hasValue && next.value != null) {
          final isMutating = next.value!.isMutating;
          final wasMutating = previous?.value?.isMutating ?? false;

          // If finished mutating successfully
          if (wasMutating && !isMutating && next.value!.mutationError == null) {
            context.pop(); // Pop back on success
          }

          // If error occurred during mutation
          if (next.value!.mutationError != null &&
              (previous?.value?.mutationError != next.value!.mutationError)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.value!.mutationError.toString())),
            );
          }
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_formKey.currentState?.saveAndValidate() ?? false) {
                final values = _formKey.currentState!.value;
                final title = values['title']?.toString() ?? '';
                final content = values['content']?.toString() ?? '';

                ref
                    .read(noteDetailNotifierProvider(widget.noteId).notifier)
                    .saveNote(title: title, content: content);
              }
            },
          ),
        ],
      ),
      body: stateAsync.when(
        data: (state) {
          return ScreenWrapper(
            child: Stack(
              children: [
                FormBuilder(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        AppTextField(
                          name: 'title',
                          label: 'Title',
                          initialValue:
                              state.note?.title ?? widget.initialTitle ?? '',
                        ),
                        const SizedBox(height: 16),
                        AppRichTextEditor(
                          name: 'content',
                          initialValue: state.content,
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.isMutating)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
