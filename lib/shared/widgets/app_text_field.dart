import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Enumerasi ragam format field teks form seperti [email], [password], atau [number].
enum AppTextFieldType {
  email,
  password,
  text,
  phone,
  number,
  price,
  url,
  multiline,
  hidden,
}

/// Pembungkus custom standard textform dari library flutter form builder.
class AppTextField extends StatefulWidget {
  /// Parameter internal name buat kunci values form builder object map data form input di screen.
  final String name;

  /// Input awalan field sebelum user memasukkan teks ketikan baru.
  final String? initialValue;

  /// String keterangan label nama/fungsi dari widget text box di antar muka aplikasi.
  final String label;

  /// Panduan bantuan ketika area box input kosong belum ada string bernilai (bukan null, namun '').
  final String? placeHolder;

  /// Jenis masukan keyboard layar ponsel (huruf / numerik / email karakter khusus dan toggle obsure sandi otomatis).
  final AppTextFieldType type;

  /// Membatasi scroll atau jumlah line break kolom yang di isikan user form builder multiline text field.
  final int? maxLines;

  /// Call function string? returning null bila error list validasi rule clear/aman, tapi kalau validasi ada yg jebol kembalikan error message l10n.
  final String? Function(String?)? validator;

  /// Capitalize perhuruf dari awalan atau word by default nyala agar string form kapitalnya natural auto correction.
  final bool enableAutoCapitalization;

  /// Flag text tidak bisa di delete/modify dan mengabaikan event ketik keyboard tap box input tetapi value form tetap masuk (disabled versi estetik).
  final bool readOnly;

  /// Teks tempelan di depan kolom input contoh 'Rp. ', '+62' dsb.
  final String? prefixText;

  /// Mirip prefixText cuma letaknya di sisi ujung akhir border input.
  final String? suffixText;

  /// Komponen widget tambahan untuk visual atau trigger navigasi popup pada awal border input.
  final Widget? prefixIcon;

  /// Seperti [prefixIcon] letak di ekor kotak biasanya buat pasang tombol visibilitas mata / copy clip.
  final Widget? suffixIcon;

  /// Event listener function trigger on string perubahan ketika penekanan karakter keyboard pada field.
  final void Function(String?)? onChanged;

  /// Opsi melumpuhkan fungsi field sama sekali.
  final bool? enabled;

  const AppTextField({
    super.key,
    required this.name,
    this.initialValue,
    required this.label,
    this.placeHolder,
    this.type = AppTextFieldType.text,
    this.maxLines,
    this.validator,
    this.enableAutoCapitalization = true,
    this.readOnly = false,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.type == AppTextFieldType.password;
    final isHidden = widget.type == AppTextFieldType.hidden;
    final isMultiline =
        widget.type == AppTextFieldType.multiline ||
        (widget.maxLines != null && widget.maxLines! > 1);

    if (isHidden) {
      return SizedBox(
        height: 0,
        child: FormBuilderTextField(
          name: widget.name,
          initialValue: widget.initialValue,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: const TextStyle(height: 0, fontSize: 0),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            constraints: BoxConstraints(maxHeight: 0, maxWidth: 0),
          ),
        ),
      );
    }

    TextInputType getKeyboardType() {
      switch (widget.type) {
        case AppTextFieldType.email:
          return TextInputType.emailAddress;
        case AppTextFieldType.phone:
          return TextInputType.phone;
        case AppTextFieldType.number:
        case AppTextFieldType.price:
          return TextInputType.number;
        case AppTextFieldType.url:
          return TextInputType.url;
        case AppTextFieldType.multiline:
          return TextInputType.multiline;
        default:
          return TextInputType.text;
      }
    }

    TextCapitalization getTextCapitalization() {
      if (!widget.enableAutoCapitalization) return TextCapitalization.none;

      switch (widget.type) {
        case AppTextFieldType.email:
        case AppTextFieldType.password:
        case AppTextFieldType.phone:
        case AppTextFieldType.number:
        case AppTextFieldType.price:
        case AppTextFieldType.url:
          return TextCapitalization.none;
        default:
          return TextCapitalization.sentences;
      }
    }

    List<TextInputFormatter> getInputFormatters() {
      switch (widget.type) {
        case AppTextFieldType.number:
          return [FilteringTextInputFormatter.digitsOnly];
        case AppTextFieldType.price:
          return [FilteringTextInputFormatter.digitsOnly, _YenPriceFormatter()];
        case AppTextFieldType.phone:
          return [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]'))];
        default:
          return [];
      }
    }

    String? getPrefixText() {
      if (widget.prefixText != null) return widget.prefixText;

      switch (widget.type) {
        case AppTextFieldType.price:
          return '¥';
        default:
          return null;
      }
    }

    String? formattedInitialValue = widget.initialValue;
    if (widget.type == AppTextFieldType.price && widget.initialValue != null) {
      formattedInitialValue = _YenPriceFormatter.formatPrice(
        widget.initialValue!,
      );
    }

    return FormBuilderTextField(
      name: widget.name,
      initialValue: formattedInitialValue,
      maxLines: isPassword ? 1 : (widget.maxLines ?? (isMultiline ? 5 : 1)),
      obscureText: isPassword ? _obscureText : false,
      keyboardType: getKeyboardType(),
      textCapitalization: getTextCapitalization(),
      inputFormatters: getInputFormatters(),
      readOnly: widget.readOnly,
      valueTransformer: (value) => value?.trim(),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.placeHolder,
        prefixText: getPrefixText(),
        suffixText: widget.suffixText,
        prefixIcon: widget.prefixIcon,
        suffixIcon:
            widget.suffixIcon ??
            (isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null),
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
      validator: widget.validator,
      enabled: widget.enabled ?? true,
    );
  }
}

class _YenPriceFormatter extends TextInputFormatter {
  static String formatPrice(String value) {
    if (value.isEmpty) return value;

    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    return _addDots(digitsOnly);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text;
    int cursorIndex = newValue.selection.end;

    int digitsBeforeCursor = 0;
    for (int i = 0; i < cursorIndex && i < newText.length; i++) {
      if (RegExp(r'\d').hasMatch(newText[i])) {
        digitsBeforeCursor++;
      }
    }

    String digitsOnly = newText.replaceAll(RegExp(r'[^\d]'), '');
    String formatted = _addDots(digitsOnly);

    int newCursorIndex = 0;
    int digitsEncountered = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (digitsEncountered == digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitsEncountered++;
      }
      newCursorIndex++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorIndex),
    );
  }

  static String _addDots(String value) {
    if (value.length <= 3) return value;

    String result = '';
    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = '.$result';
      }
      result = value[i] + result;
      count++;
    }

    return result;
  }
}
