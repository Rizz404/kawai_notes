import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Item (opsi) yang dipakai di dalam kumpulan chip pilihan.
class AppChoiceChipItem<T> {
  final T value;
  final String label;

  const AppChoiceChipItem({required this.value, required this.label});
}

/// Form field untuk menyajikan input pilihan tunggal (single choice) dengan tampilan Chip UI.
/// Alternatif untuk [AppRadioGroup].
class AppChoiceChip<T> extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari kumpulan chip ini.
  final String? label;

  /// Menandakan apakah isian ini wajib diisi oleh pengguna.
  final bool isRequired;

  /// Daftar pilihan item (chip) yang bisa dipilih.
  final List<AppChoiceChipItem<T>> options;

  /// Nilai bawaan (default) saat pertama kali ditampilkan.
  final T? initialValue;

  /// Fungsi yang dieksekusi saat pengguna mengubah pilihan.
  final ValueChanged<T?>? onChanged;

  /// Fungsi validasi.
  final String? Function(T?)? validator;

  /// Padding antar elemen (chip).
  final double spacing;

  const AppChoiceChip({
    super.key,
    required this.name,
    this.label,
    this.isRequired = false,
    required this.options,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              AppText(
                label!,
                style: AppTextStyle.bodySmall,
                fontWeight: FontWeight.w600,
              ),
              if (isRequired)
                AppText(
                  ' *',
                  color: context.semantic.error,
                  style: AppTextStyle.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        FormBuilderChoiceChips<T>(
          name: name,
          initialValue: initialValue,
          onChanged: onChanged,
          validator: validator,
          spacing: spacing,
          selectedColor: context.colorScheme.primary,
          backgroundColor: context.colors.surfaceVariant,
          labelStyle: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          options: options.map((option) {
            return FormBuilderChipOption<T>(
              value: option.value,
              child: AppText(option.label),
            );
          }).toList(),
        ),
      ],
    );
  }
}
