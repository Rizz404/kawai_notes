import 'package:flutter/material.dart';

enum MutationType {
  create('create'),
  update('update'),
  delete('delete');

  const MutationType(this.value);

  final String value;

  String get label => value;

  IconData get icon {
    switch (this) {
      case MutationType.create:
        return Icons.add_circle_outline;
      case MutationType.update:
        return Icons.edit;
      case MutationType.delete:
        return Icons.delete_outline;
    }
  }
}
