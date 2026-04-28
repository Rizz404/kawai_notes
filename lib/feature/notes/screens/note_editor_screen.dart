import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/core/utils/toast_utils.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/shared/widgets/app_rich_text_editor.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/app_text_field.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

  bool _isPinned = false;
  bool _isPinnedInitialized = false;
  bool _isDirty = false;

  int? _colorValue;
  String? _customBackgroundImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ! hanya simpan saat benar-benar paused agar updatedAt tidak berubah saat buka note
    if (state == AppLifecycleState.paused) {
      _saveNoteBackground();
    }
  }

  Future<void> _pickColor() async {
    final Color newColor = await showColorPickerDialog(
      context,
      _colorValue != null ? Color(_colorValue!) : Colors.white,
      title: AppText(context.l10n.notesPickColor, fontSize: 20),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: true,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    );

    setState(() {
      _colorValue = newColor.toARGB32();
      _customBackgroundImage = null;
      _isDirty = true;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final extension = path.extension(pickedFile.path);
      final newPath = path.join(
        appDir.path,
        'note_bg_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await File(pickedFile.path).copy(newPath);

      setState(() {
        _customBackgroundImage = newPath;
        _colorValue = null;
        _isDirty = true;
      });
    }
  }

  void _saveNoteBackground() {
    // ! jangan simpan sebelum state pin diinisialisasi agar isPinned tidak ter-reset
    if (!_isPinnedInitialized) return;
    if (!_isDirty) return;

    _formKey.currentState?.save(); // save data without validating
    final values = _formKey.currentState?.value;
    if (values == null) return;

    final rawTitle = values['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty ? context.l10n.notesUntitledNote : rawTitle;
    final content = values['content']?.toString() ?? '';

    // if new note and completely empty, skip saving
    if (widget.noteId == null && rawTitle.isEmpty && content.isEmpty) return;

    Future.microtask(() {
      if (mounted) {
        ref
            .read(noteDetailNotifierProvider(widget.noteId).notifier)
            .saveNote(
              title: title,
              content: content,
              isPinned: _isPinned,
              colorValue: _colorValue,
              customBackgroundImage: _customBackgroundImage,
            );
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
          if (!_isPinnedInitialized) {
            setState(() {
              _isPinned = next.value!.note?.isPinned ?? false;
              _colorValue = next.value!.note?.colorValue;
              _customBackgroundImage = next.value!.note?.customBackgroundImage;
              _isPinnedInitialized = true;
            });
          }

          if (next.value!.mutationError != null &&
              (previous?.value?.mutationError != next.value!.mutationError)) {
            if (mounted) {
              AppToast.error(next.value!.mutationError.toString());
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
      child: Container(
        decoration: _customBackgroundImage != null
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(_customBackgroundImage!)),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: Scaffold(
          backgroundColor: _colorValue != null
              ? Color(_colorValue!)
              : (_customBackgroundImage != null ? Colors.transparent : null),
          appBar: AppBar(
            backgroundColor:
                _colorValue != null || _customBackgroundImage != null
                ? Colors.transparent
                : null,
            title: AppText(
              widget.noteId == null
                  ? context.l10n.notesNew
                  : context.l10n.notesEdit,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                onPressed: _pickColor,
              ),
              IconButton(
                icon: const Icon(Icons.image_outlined),
                onPressed: _pickImage,
              ),
              if (_colorValue != null || _customBackgroundImage != null)
                IconButton(
                  icon: const Icon(Icons.format_color_reset),
                  onPressed: () => setState(() {
                    _colorValue = null;
                    _customBackgroundImage = null;
                    _isDirty = true;
                  }),
                ),
              IconButton(
                icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                onPressed: () => setState(() {
                  _isPinned = !_isPinned;
                  _isDirty = true;
                }),
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
              Widget contentWrapper = ScreenWrapper(
                child: Stack(
                  children: [
                    FormBuilder(
                      key: _formKey,
                      child: Column(
                        children: [
                          AppTextField(
                            name: 'title',
                            label: context.l10n.notesTitleOptional,
                            placeHolder: context.l10n.notesUntitledNote,
                            initialValue:
                                (state.note?.title == 'Untitled' ||
                                    state.note?.title ==
                                        context.l10n.notesUntitledNote)
                                ? ''
                                : (state.note?.title ??
                                      widget.initialTitle ??
                                      ''),
                            isBorderless: true,
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            onChanged: (_) => _isDirty = true,
                          ),
                          Expanded(
                            child: AppRichTextEditor(
                              name: 'content',
                              initialValue: state.content,
                              showToolbar: true,
                              focusNode: _contentFocusNode,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                              onChanged: (_) => _isDirty = true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              return contentWrapper;
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: AppText(context.l10n.notesError(error.toString())),
            ),
          ),
        ),
      ),
    );
  }
}
