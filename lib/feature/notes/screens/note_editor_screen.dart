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

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormBuilderState>();
  final FocusNode _contentFocusNode = FocusNode();
  bool _showToolbar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveNoteBackground();
    }
  }

  void _saveNoteBackground() {
    _formKey.currentState?.save(); // save data without validating
    final values = _formKey.currentState?.value;
    if (values == null) return;

    final rawTitle = values['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty ? 'Untitled' : rawTitle;
    final content = values['content']?.toString() ?? '';

    // if new note and completely empty, skip saving
    if (widget.noteId == null && rawTitle.isEmpty && content.isEmpty) return;

    Future.microtask(() {
      if (mounted) {
        ref
            .read(noteDetailNotifierProvider(widget.noteId).notifier)
            .saveNote(title: title, content: content);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(noteDetailNotifierProvider(widget.noteId));

    ref.listen<AsyncValue<NoteDetailState>>(
      noteDetailNotifierProvider(widget.noteId),
      (previous, next) {
        if (next.hasValue && next.value != null) {
          if (next.value!.mutationError != null &&
              (previous?.value?.mutationError != next.value!.mutationError)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(next.value!.mutationError.toString())),
              );
            }
          }
        }
      },
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveNoteBackground();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
          actions: [
            IconButton(
              icon: Icon(
                _showToolbar ? Icons.text_format : Icons.text_format_outlined,
              ),
              onPressed: () => setState(() => _showToolbar = !_showToolbar),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                context.pop();
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
                            label: 'Title (Optional)',
                            initialValue:
                                state.note?.title ?? widget.initialTitle ?? '',
                          ),
                          const SizedBox(height: 16),
                          AppRichTextEditor(
                            name: 'content',
                            initialValue: state.content,
                            showToolbar: _showToolbar,
                            focusNode: _contentFocusNode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
