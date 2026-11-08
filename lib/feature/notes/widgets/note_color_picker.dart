import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

/// Shows the note colour picker. Returns null when the dialog is cancelled
/// or dismissed, so callers can leave the note untouched.
Future<Color?> showNoteColorPicker(BuildContext context, Color initial) async {
  var selected = initial;
  final confirmed = await ColorPicker(
    color: initial,
    onColorChanged: (color) => selected = color,
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
  ).showPickerDialog(context);
  return confirmed ? selected : null;
}
