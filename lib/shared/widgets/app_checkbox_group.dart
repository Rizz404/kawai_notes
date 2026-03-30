import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Item (opsi) yang dipakai di dalam [AppCheckboxGroup].
class AppCheckboxGroupItem<T> {
  final T value;
  final String label;

  const AppCheckboxGroupItem({required this.value, required this.label});
}

/// Form field untuk menyajikan input seleksi jamak (multiple choice) menggunakan checkbox.
class AppCheckboxGroup<T> extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari kumpulan checkbox ini.
  final String? label;

  /// Menandakan apakah isian ini wajib diisi oleh pengguna (minimal pilih 1 opsi).
  final bool isRequired;

  /// Daftar pilihan item (checkbox) yang bisa dipilih.
  final List<AppCheckboxGroupItem<T>> options;

  /// Rentetan nilai bawaan (default) saat pertama kali ditampilkan.
  final List<T>? initialValue;

  /// Fungsi yang dieksekusi saat pengguna menambah/menghapus pilihan.
  final ValueChanged<List<T>?>? onChanged;

  /// Fungsi validasi kumpulan checkbox.
  final String? Function(List<T>?)? validator;

  /// Orientasi dari himpunan opsi (vertikal atau horizontal).
  final OptionsOrientation orientation;

  const AppCheckboxGroup({
    super.key,
    required this.name,
    this.label,
    this.isRequired = false,
    required this.options,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.orientation = OptionsOrientation.vertical,
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
        FormBuilderCheckboxGroup<T>(
          name: name,
          initialValue: initialValue,
          onChanged: onChanged,
          validator: validator,
          orientation: orientation,
          activeColor: context.colorScheme.primary,
          options: options.map((option) {
            return FormBuilderFieldOption<T>(
              value: option.value,
              child: AppText(option.label, style: AppTextStyle.bodyMedium),
            );
          }).toList(),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ],
    );
  }
}
