import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Form field untuk menyajikan input berupa switch/toggle.
class AppSwitch extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul utama dari switch ini.
  final String title;

  /// Penjelasan tambahan (opsional) di bawah judul.
  final String? subtitle;

  /// Nilai bawaan (default) saat pertama kali ditampilkan.
  final bool initialValue;

  /// Tereksekusi setiap kali nilai (status) switch berubah.
  final ValueChanged<bool?>? onChanged;

  /// Fungsi validasi.
  final String? Function(bool?)? validator;

  /// Menentukan apakah switch ini bisa diubah nilainya (tidak terkunci).
  final bool enabled;

  const AppSwitch({
    super.key,
    required this.name,
    required this.title,
    this.subtitle,
    this.initialValue = false,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderSwitch(
      name: name,
      title: AppText(
        title,
        style: AppTextStyle.bodyMedium,
        fontWeight: FontWeight.w500,
        color: enabled
            ? context.colors.textPrimary
            : context.colors.textDisabled,
      ),
      subtitle: subtitle != null
          ? AppText(
              subtitle!,
              style: AppTextStyle.bodySmall,
              color: enabled
                  ? context.colors.textSecondary
                  : context.colors.textDisabled,
            )
          : null,
      initialValue: initialValue,
      onChanged: onChanged,
      validator: validator,
      enabled: enabled,
      activeColor: context.colorScheme.primary,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
