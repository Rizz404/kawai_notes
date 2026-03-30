import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Komponen checkbox kustom yang mengintegrasikan form builder dan pengaturan theme aplikasi.
class AppCheckbox extends StatelessWidget {
  /// Nama dari form field checkbox ini.
  final String name;

  /// Widget yang akan ditampilkan sebagai judul checkbox.
  final Widget title;

  /// Fungsi opsional untuk melakukan validasi pada nilai checkbox.
  final String? Function(bool?)? validator;

  /// Nilai awal yang digunakan saat checkbox pertama kali dibuat.
  final bool? initialValue;

  /// Konstruktor utama dari komponen AppCheckbox.
  const AppCheckbox({
    super.key,
    required this.name,
    required this.title,
    this.validator,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderCheckbox(
      name: name,
      title: title,
      validator: validator,
      initialValue: initialValue,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: context.colors.primary,
      checkColor: context.colors.textOnPrimary,
    );
  }
}
