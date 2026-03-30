import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Model class untuk merpresentasikan sebuah item di dalam dropdown.
class AppDropdownItem<T> {
  /// Nilai sebenarnya dari item tersebut yang akan disimpan atau dikirim.
  final T value;

  /// Label teks yang akan dirender di UI dropdown.
  final String label;

  /// Widget icon opsional yang dirender bersisian dengan label.
  final Widget? icon;

  const AppDropdownItem({required this.value, required this.label, this.icon});
}

/// Widget dropdown kustom yang merangkum fungsionalitas FormBuilderDropdown dengan theme standar aplikasi.
class AppDropdown<T> extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Nilai initial (bawaan) yang terpilih ketika dibuat.
  final T? initialValue;

  /// Kumpulan list opsi yang ditampilkan di dalam dropdown.
  final List<AppDropdownItem<T>> items;

  /// Fungsi callback yang dipicu ketika opsi terpilih berubah.
  final ValueChanged<T?>? onChanged;

  /// Teks petunjuk saat opsi belum ada yang dipilih (placeholder).
  final String? hintText;

  /// Label atau judul dari isian dropdown ini.
  final String? label;

  /// Penanda apakah interaksi dengan dropdown diizinkan.
  final bool enabled;

  /// Padding internal di dalam bingkai input form field.
  final EdgeInsetsGeometry? contentPadding;

  /// Warna latar dalam dari input field.
  final Color? fillColor;

  /// Widget icon tambahan yang ditempatkan di depan area field.
  final Widget? prefixIcon;

  /// Menentukan apakah isinya direnggangkan mengisi sisa space pada row.
  final bool isExpanded;

  /// Lebar mutlak dari komponen dropdown (jika ditentukan).
  final double? width;

  /// Fungsi yang memvalidasi opsi yang dipilih melalui form key.
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.name,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.hintText,
    this.label,
    this.enabled = true,
    this.contentPadding,
    this.fillColor,
    this.prefixIcon,
    this.isExpanded = true,
    this.width,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    Widget dropdown = FormBuilderDropdown<T>(
      name: name,
      initialValue: initialValue,
      enabled: enabled,
      onChanged: onChanged,
      validator: validator,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
              Flexible(
                child: AppText(
                  item.label,
                  style: AppTextStyle.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      isExpanded: isExpanded,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? context.l10n.appDropdownSelectOption,
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.textTertiary,
        ),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: fillColor ?? context.colors.surface,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colors.disabled, width: 1),
        ),
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colors.textPrimary,
      ),
      dropdownColor: context.colors.surface,
      iconEnabledColor: context.colors.textSecondary,
      iconDisabledColor: context.colors.textDisabled,
    );

    if (width != null) {
      dropdown = SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }
}

extension AppDropdownExtensions on AppDropdown<dynamic> {
  static List<AppDropdownItem<String>> createFilterItems({
    required String allLabel,
    required List<String> filterValues,
    required List<String> filterLabels,
    List<IconData>? filterIcons,
  }) {
    final items = <AppDropdownItem<String>>[
      AppDropdownItem(
        value: 'all',
        label: allLabel,
        icon: const Icon(Icons.list_alt, size: 18),
      ),
    ];

    for (int i = 0; i < filterValues.length; i++) {
      items.add(
        AppDropdownItem(
          value: filterValues[i],
          label: filterLabels[i],
          icon: filterIcons != null && i < filterIcons.length
              ? Icon(filterIcons[i], size: 18)
              : null,
        ),
      );
    }

    return items;
  }
}
