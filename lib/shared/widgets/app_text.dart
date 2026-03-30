import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

/// Enum yang mewakili setiap style typography pada aplikasi.
enum AppTextStyle {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
}

/// Widget teks kustom yang sudah terintegrasi dengan konfigurasi [AppTextStyle] dan warna theme.
class AppText extends StatelessWidget {
  /// Nilai teks yang akan ditampilkan.
  final String text;

  /// Preferensi style dasar untuk ukuran dan ketebalan teks (dari [AppTextStyle]).
  final AppTextStyle? style;

  /// Cara mengatur perataan (alignment) untuk teks.
  final TextAlign? textAlign;

  /// Arah tulisan teks, contohnya kiri-ke-kanan atau kanan-ke-kiri.
  final TextDirection? textDirection;

  /// Identifier dari sebuah wilayah atau bahasa yang mempengaruhi format layout teks.
  final Locale? locale;

  /// Menentukan apakah teks harus dibungkus (wrap) jika melebihi batas baris.
  final bool? softWrap;

  /// Perilaku teks ketika lebarnya melebihi lebar kontainer.
  final TextOverflow? overflow;

  /// Objek text scaler yang mengatur penambahan atau pengurangan ukuran teks otomatis dari setting sistem.
  final TextScaler? textScaler;

  /// Jumlah baris maksimum teks yang akan dirender.
  final int? maxLines;

  /// Label semantik yang digunakan oleh alat aksesibilitas.
  final String? semanticsLabel;

  /// Menentukan lebar dasar (width basis) yang dipakai untuk menghitung ukuran teks.
  final TextWidthBasis? textWidthBasis;

  /// Pengaturan perilaku tinggi baris (line height) pada teks.
  final TextHeightBehavior? textHeightBehavior;

  /// Warna yang dipakai untuk menyoroti (highlight) teks ini ketika dipilih.
  final Color? selectionColor;

  /// Gaya kustom tambahan yang akan digabungkan ke konfigurasi utama.
  final TextStyle? customStyle;

  /// Warna tulisan teks individual.
  final Color? color;

  /// Ukuran font spesifik yang menimpa (override) ukuran dasar yang ada.
  final double? fontSize;

  /// Ketebalan tulisan teks secara absolut.
  final FontWeight? fontWeight;

  /// Style tulisan spesifik misalnya cetak miring (italic).
  final FontStyle? fontStyle;

  /// Jarak spasi antar huruf untuk teks.
  final double? letterSpacing;

  /// Tinggi spesifik dari setiap baris teks.
  final double? lineHeight;

  /// Dekorasi linear teks, seperti underline (garis bawah) dan sejenisnya.
  final TextDecoration? decoration;

  /// Konstruktor utama dari komponen AppText.
  const AppText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.customStyle,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.letterSpacing,
    this.lineHeight,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    TextStyle getBaseStyle() {
      final selectedStyle = style ?? AppTextStyle.bodyMedium;

      switch (selectedStyle) {
        case AppTextStyle.displayLarge:
          return textTheme.displayLarge!;
        case AppTextStyle.displayMedium:
          return textTheme.displayMedium!;
        case AppTextStyle.displaySmall:
          return textTheme.displaySmall!;
        case AppTextStyle.headlineLarge:
          return textTheme.headlineLarge!;
        case AppTextStyle.headlineMedium:
          return textTheme.headlineMedium!;
        case AppTextStyle.headlineSmall:
          return textTheme.headlineSmall!;
        case AppTextStyle.titleLarge:
          return textTheme.titleLarge!;
        case AppTextStyle.titleMedium:
          return textTheme.titleMedium!;
        case AppTextStyle.titleSmall:
          return textTheme.titleSmall!;
        case AppTextStyle.bodyLarge:
          return textTheme.bodyLarge!;
        case AppTextStyle.bodyMedium:
          return textTheme.bodyMedium!;
        case AppTextStyle.bodySmall:
          return textTheme.bodySmall!;
        case AppTextStyle.labelLarge:
          return textTheme.labelLarge!;
        case AppTextStyle.labelMedium:
          return textTheme.labelMedium!;
        case AppTextStyle.labelSmall:
          return textTheme.labelSmall!;
      }
    }

    TextStyle baseStyle = getBaseStyle();

    if (customStyle != null) {
      baseStyle = baseStyle.merge(customStyle);
    }

    final finalStyle = baseStyle.copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: lineHeight,
      decoration: decoration,
    );

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
