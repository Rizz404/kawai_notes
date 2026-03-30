import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';

/// Extension untuk mempermudah format angka ke dalam bentuk currency.
extension NumExtension on num {
  /// Melakukan format angka ke dalam string Yen dengan pemisah titik.
  String toYen() {
    final formatter = _YenFormatter();
    return formatter.format(this);
  }

  /// Melakukan format angka ke dalam format singkat string Yen (contoh: ¥ 1.5M).
  String toYenShort() {
    String billionSuffix = 'M';
    String millionSuffix = 'jt';
    String thousandSuffix = 'rb';

    try {
      final l10n = LocalizationExtension.current;
      billionSuffix = l10n.currencyBillionSuffix;
      millionSuffix = l10n.currencyMillionSuffix;
      thousandSuffix = l10n.currencyThousandSuffix;
    } catch (_) {}

    if (this >= 1000000000) {
      double result = this / 1000000000;
      return '¥ ${result.toStringAsFixed(1).replaceAll('.0', '')}$billionSuffix';
    } else if (this >= 1000000) {
      double result = this / 1000000;
      return '¥ ${result.toStringAsFixed(1).replaceAll('.0', '')}$millionSuffix';
    } else if (this >= 1000) {
      double result = this / 1000;
      return '¥ ${result.toStringAsFixed(1).replaceAll('.0', '')}$thousandSuffix';
    }

    return '¥ ${toStringAsFixed(0)}';
  }
}

class _YenFormatter {
  String format(num value) {
    final intValue = value.toInt();
    final stringValue = intValue.toString();
    return '¥ ${_formatWithDots(stringValue)}';
  }

  String _formatWithDots(String value) {
    if (value.length <= 3) return value;

    final result = StringBuffer();
    int count = 0;

    for (int i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write('.');
      }
      result.write(value[i]);
      count++;
    }

    return result.toString().split('').reversed.join('');
  }
}
