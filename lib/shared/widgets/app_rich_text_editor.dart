import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppRichTextEditor extends FormBuilderField<String> {
  final bool showToolbar;
  final Widget? bottomActions;
  final TextStyle? textStyle;

  AppRichTextEditor({
    super.key,
    required super.name,
    this.showToolbar = false,
    this.bottomActions,
    this.textStyle,
    super.focusNode,
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
           final widget = state.widget;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Expanded(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8),
                   child: QuillEditor.basic(
                     focusNode: widget.focusNode,
                     controller: state._quillController,
                     config: QuillEditorConfig(
                       customStyles: DefaultStyles(
                         paragraph: DefaultTextBlockStyle(
                           widget.textStyle ??
                               field.context.textTheme.bodyLarge!.copyWith(
                                 fontSize: 16,
                                 height: 1.5,
                               ),
                           const HorizontalSpacing(0, 0),
                           const VerticalSpacing(0, 0),
                           const VerticalSpacing(0, 0),
                           null,
                         ),
                       ),
                     ),
                   ),
                 ),
               ),
               if (widget.showToolbar)
                 Row(
                   children: [
                     Expanded(
                       child: QuillSimpleToolbar(
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
                     ),
                     IconButton(
                       icon: const Icon(Icons.image),
                       onPressed: state._pickAndInsertImage,
                       tooltip: 'Insert Image',
                     ),
                   ],
                 ),
               if (widget.bottomActions != null) widget.bottomActions!,
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
  final ImagePicker _picker = ImagePicker();

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

    Document document;
    if (initialMarkdown.isEmpty) {
      document = Document();
    } else {
      final delta = MarkdownToDelta(
        markdownDocument: mdDocument,
      ).convert(initialMarkdown);

      if (delta.isEmpty) {
        document = Document();
      } else {
        document = Document.fromDelta(delta);
      }
    }

    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _quillController.document.changes.listen((event) {
      final currentDelta = _quillController.document.toDelta();
      final markdown = DeltaToMarkdown().convert(currentDelta);

      // Update form builder value
      didChange(markdown);
    });
  }

  Future<void> _pickAndInsertImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(docsDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(image.path)}';
      final savedImage = File(p.join(imagesDir.path, fileName));
      await File(image.path).copy(savedImage.path);

      // We insert posisional markdown string
      final markdownImage = '\n![image](${savedImage.path})\n';

      final offset = _quillController.selection.baseOffset;
      _quillController.document.insert(offset < 0 ? 0 : offset, markdownImage);
      _quillController.moveCursorToPosition(
        (offset < 0 ? 0 : offset) + markdownImage.length,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
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
