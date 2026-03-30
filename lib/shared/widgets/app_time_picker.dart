import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Form field kustom untuk menyajikan dialog pemilih waktu (time picker).
class AppTimePicker extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul instruksional dari time picker ini.
  final String label;

  /// Nilai waktu bawaan saat dialog pertama kali dirender.
  final TimeOfDay? initialValue;

  /// Penanda apakah input ini bisa diklik dan diinteraksikan.
  final bool enabled;

  const AppTimePicker({
    super.key,
    required this.name,
    required this.label,
    this.initialValue,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<TimeOfDay>(
      name: name,
      initialValue: initialValue,
      enabled: enabled,
      builder: (FormFieldState<TimeOfDay> field) {
        return InkWell(
          onTap: enabled
              ? () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: field.value ?? TimeOfDay.now(),
                  );
                  if (time != null) {
                    field.didChange(time);
                  }
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.access_time),
              filled: !enabled,
              fillColor: !enabled
                  ? context.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    )
                  : null,
            ),
            child: Text(
              field.value != null
                  ? field.value!.format(context)
                  : context.l10n.sharedTimePlaceholder,
              style: TextStyle(
                color: enabled
                    ? null
                    : context.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}
