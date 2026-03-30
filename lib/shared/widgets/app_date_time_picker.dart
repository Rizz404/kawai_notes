import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Form field untuk menyajikan input kalender atau waktu.
class AppDateTimePicker extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari input kalender ini.
  final String label;

  /// Tipe input yang menentukan apakah kalender dirender sebagai tanggal, waktu, atau keduanya.
  final InputType inputType;

  /// Icon opsional yang mendampingi input datetime.
  final IconData? icon;

  /// Fungsi validasi untuk nilai datetime yang diinput oleh pengguna.
  final String? Function(DateTime?)? validator;

  /// Nilai awal bawaan yang ditampilkan sebelum pengguna berinteraksi.
  final DateTime? initialValue;

  /// Batas minimal kalender yang dapat dipilih oleh pengguna.
  final DateTime? firstDate;

  /// Batas maksimal kalender yang dapat dipilih oleh pengguna.
  final DateTime? lastDate;

  /// Fungsi callback yang dipanggil ketika nilai berubah.
  final void Function(DateTime?)? onChanged;

  /// Penanda apakah input ini bisa diubah atau di-disable.
  final bool enabled;

  const AppDateTimePicker({
    super.key,
    required this.name,
    required this.label,
    this.inputType = InputType.date,
    this.icon,
    this.validator,
    this.initialValue,
    this.firstDate,
    this.lastDate,
    this.onChanged,
    this.enabled = true,
  });

  IconData get _defaultIcon {
    switch (inputType) {
      case InputType.time:
        return Icons.access_time_outlined;
      case InputType.both:
        return Icons.calendar_month_outlined;
      case InputType.date:
        return Icons.calendar_today_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderDateTimePicker(
      name: name,
      inputType: inputType,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Icon(icon ?? _defaultIcon),
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.semantic.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
      initialValue: initialValue,
      firstDate: firstDate,
      lastDate: lastDate,
      valueTransformer: (value) => value?.toLocal(),
    );
  }
}
