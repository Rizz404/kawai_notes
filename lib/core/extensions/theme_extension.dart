import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/themes/app_colors.dart';
import 'package:flutter_setup_riverpod/core/themes/app_theme.dart';

/// Extension untuk mempermudah akses properti theme dari BuildContext.
extension ThemeExtension on BuildContext {
  /// Mendapatkan instance ThemeData saat ini.
  ThemeData get theme => Theme.of(this);

  /// Mendapatkan TextTheme dari file saat ini.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Mendapatkan ColorScheme saat ini.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Mendapatkan CupertinoThemeData saat ini.
  CupertinoThemeData get cupertinoTheme => CupertinoTheme.of(this);

  /// Mengecek apakah theme saat ini sedang menggunakan dark mode.
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Mendapatkan ThemeData aplikasi berdasarkan status dark mode.
  ThemeData get appTheme =>
      isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  /// Mendapatkan CupertinoThemeData aplikasi berdasarkan status dark mode.
  CupertinoThemeData get appCupertinoTheme =>
      isDarkMode ? AppTheme.cupertinoDarkTheme : AppTheme.cupertinoLightTheme;

  /// Mendapatkan ThemeData default versi light.
  ThemeData get appLightTheme => AppTheme.lightTheme;

  /// Mendapatkan ThemeData default versi dark.
  ThemeData get appDarkTheme => AppTheme.darkTheme;

  /// Mendapatkan CupertinoThemeData default versi light.
  CupertinoThemeData get appCupertinoLightTheme => AppTheme.cupertinoLightTheme;

  /// Mendapatkan CupertinoThemeData default versi dark.
  CupertinoThemeData get appCupertinoDarkTheme => AppTheme.cupertinoDarkTheme;

  /// Mendapatkan varian semantic color yang digunakan pada aplikasi.
  SemanticColors get semantic => AppColors.semantic;
}

/// Extension untuk mengakses custom app colors dari BuildContext.
extension ThemeColors on BuildContext {
  /// Mendapatkan custom color aplikasi sesuai dengan brightness saat ini.
  AppColorsTheme get colors {
    return Theme.of(this).brightness == Brightness.light
        ? AppColorsTheme.light()
        : AppColorsTheme.dark();
  }
}
