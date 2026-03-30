import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';

enum SortOrder {
  asc('asc'),
  desc('desc');

  const SortOrder(this.value);
  final String value;

  String get label {
    final l10n = LocalizationExtension.current;
    switch (this) {
      case SortOrder.asc:
        return l10n.enumSortOrderAsc;
      case SortOrder.desc:
        return l10n.enumSortOrderDesc;
    }
  }

  IconData get icon {
    switch (this) {
      case SortOrder.asc:
        return Icons.arrow_upward;
      case SortOrder.desc:
        return Icons.arrow_downward;
    }
  }
}
