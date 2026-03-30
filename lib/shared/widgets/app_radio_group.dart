import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Form field untuk menyajikan kumpulan radio button secara dinamis.
class AppRadioGroup<T extends Object> extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari kumpulan radio button yang ditampilkan.
  final String label;

  /// Fungsi validasi untuk inputan ketika form disubmit.
  final String? Function(T?)? validator;

  /// Daftar opsi yang akan dirender sebagai radio button secara individual.
  final List<FormBuilderFieldOption<T>> options;

  /// Posisi kontrol (indicator bulat) dari setiap item opsi.
  final ControlAffinity controlAffinity;

  /// Jarak pemisah antar radio button (widget separator).
  final Widget? separator;

  /// Konstruktor dasar dari AppRadioGroup.
  const AppRadioGroup({
    super.key,
    required this.name,
    required this.label,
    required this.options,
    this.validator,
    this.controlAffinity = ControlAffinity.leading,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderRadioGroup<T>(
      name: name,
      decoration: InputDecoration(
        labelText: label,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        labelStyle: context.textTheme.bodyLarge?.copyWith(
          color: context.theme.inputDecorationTheme.labelStyle?.color,
        ),
      ),
      validator: validator,
      options: options,
      controlAffinity: controlAffinity,
      separator: separator ?? const SizedBox(width: 20),
    );
  }
}
