import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';
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
  Note? _existingNote;
  bool _isLoading = false;
  String _initialContent = '';

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    if (widget.noteId != null) {
      setState(() => _isLoading = true);
      final repository = ref.read(noteRepositoryProvider);

      _existingNote = repository.getNote(widget.noteId!);
      if (_existingNote != null) {
        _initialContent = await repository.readNoteContent(
          _existingNote!.contentPath,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      final title = values['title'] as String;
      final content = values['content'] as String? ?? '';

      final repository = ref.read(noteRepositoryProvider);
      await repository.saveNote(
        id: _existingNote?.id ?? 0,
        ulid: _existingNote?.ulid,
        title: title,
        content: content,
      );

      // refresh notes on list
      ref.invalidate(allNotesProvider);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _saveNote(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScreenWrapper(
              child: FormBuilder(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AppTextField(
                        name: 'title',
                        label: 'Title',
                        initialValue:
                            _existingNote?.title ?? widget.initialTitle ?? '',
                      ),
                      const SizedBox(height: 16),
                      AppRichTextEditor(
                        name: 'content',
                        initialValue: _initialContent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
