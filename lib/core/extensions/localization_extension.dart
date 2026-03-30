import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/l10n/app_localizations.dart';

/// Global key untuk mengakses referensi ke root dari material app navigator.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Extension untuk mempermudah akses resource localization dari BuildContext.
extension LocalizationExtension on BuildContext {
  /// Mendapatkan instance dari AppLocalizations saat ini.
  L10n get l10n => L10n.of(this)!;

  /// Mendapatkan language code dari locale saat ini.
  String get locale => Localizations.localeOf(this).languageCode;

  /// Mengecek apakah locale saat ini menggunakan bahasa Inggris.
  bool get isEnglish => locale == 'en';

  /// Mengecek apakah locale saat ini menggunakan bahasa Jepang.
  bool get isJapanese => locale == 'ja';

  /// Mendapatkan instance AppLocalizations secara global tanpa BuildContext.
  static L10n get current {
    final context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception(
        'Navigator context is null. Ensure router is initialized.',
      );
    }
    return L10n.of(context)!;
  }
}
