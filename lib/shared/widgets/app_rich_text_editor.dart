import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

class AppRichTextEditor extends FormBuilderField<String> {
  AppRichTextEditor({
    super.key,
    required super.name,
    super.validator,
    super.onChanged,
    super.valueTransformer,
    super.enabled = true,
    super.onSaved,
    super.autovalidateMode = AutovalidateMode.disabled,
    super.initialValue,
    super.restorationId,
  }) : super(
         builder: (FormFieldState<String?> field) {
           final state = field as _AppRichTextEditorState;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               QuillSimpleToolbar(
                 controller: state._quillController,
                 config: const QuillSimpleToolbarConfig(
                   showFontFamily: false,
                   showFontSize: false,
                   showSubscript: false,
                   showSuperscript: false,
                   showInlineCode: false,
                   showColorButton: false,
                   showBackgroundColorButton: false,
                   showClearFormat: false,
                   showAlignmentButtons: false,
                   showDirection: false,
                 ),
               ),
               Container(
                 height: 300, // or flexible
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: field.context.colors.surface,
                   border: Border.all(
                     color: field.hasError
                         ? field.context.semantic.error
                         : field.context.colors.border,
                   ),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: QuillEditor.basic(
                   controller: state._quillController,
                   config: QuillEditorConfig(
                     customStyles: DefaultStyles(
                       paragraph: DefaultTextBlockStyle(
                         field.context.textTheme.bodyMedium!,
                         const HorizontalSpacing(0, 0),
                         const VerticalSpacing(0, 0),
                         const VerticalSpacing(0, 0),
                         null,
                       ),
                     ),
                   ),
                 ),
               ),
               if (field.hasError) ...[
                 const SizedBox(height: 4),
                 Text(
                   field.errorText!,
                   style: TextStyle(
                     color: field.context.semantic.error,
                     fontSize: 12,
                   ),
                 ),
               ],
             ],
           );
         },
       );

  @override
  FormBuilderFieldState<AppRichTextEditor, String> createState() =>
      _AppRichTextEditorState();
}

class _AppRichTextEditorState
    extends FormBuilderFieldState<AppRichTextEditor, String> {
  late QuillController _quillController;

  @override
  void initState() {
    super.initState();
    _initQuillController();
  }

  void _initQuillController() {
    final mdDocument = md.Document(
      encodeHtml: false,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final String initialMarkdown = widget.initialValue ?? '';
    final delta = MarkdownToDelta(
      markdownDocument: mdDocument,
    ).convert(initialMarkdown);

    _quillController = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _quillController.document.changes.listen((event) {
      final currentDelta = _quillController.document.toDelta();
      final markdown = DeltaToMarkdown().convert(currentDelta);

      // Update form builder value
      didChange(markdown);
    });
  }

  @override
  void reset() {
    super.reset();
    _initQuillController();
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }
}
