import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Form field untuk menyajikan input slider dalam rentang nilai tertentu.
class AppSlider extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari slider ini.
  final String? label;

  /// Menandakan apakah input slider wajib diisi (opsional, karena ada nilai awal).
  final bool isRequired;

  /// Nilai batas bawah slider.
  final double min;

  /// Nilai batas atas slider.
  final double max;

  /// Nilai bawaan di mana slider bermula.
  final double initialValue;

  /// Jika diisi, slider akan memiliki batasan langkah berupa titik diskrit sebesar _divisions_.
  final int? divisions;

  /// Fungsi yang dieksekusi setiap kali nilai slider berubah.
  final ValueChanged<double?>? onChanged;

  /// Fungsi validasi kustom.
  final String? Function(double?)? validator;

  const AppSlider({
    super.key,
    required this.name,
    this.label,
    this.isRequired = false,
    required this.min,
    required this.max,
    required this.initialValue,
    this.divisions,
    this.onChanged,
    this.validator,
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
        FormBuilderSlider(
          name: name,
          min: min,
          max: max,
          initialValue: initialValue,
          divisions: divisions,
          onChanged: onChanged,
          validator: validator,
          activeColor: context.colorScheme.primary,
          inactiveColor: context.colors.border,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
