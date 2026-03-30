import 'package:flutter/material.dart';

/// Widget wrapper dasar yang memberikan SafeArea dan padding standar pada suatu screen.
class ScreenWrapper extends StatelessWidget {
  /// Widget children yang akan ditampilkan di dalam wrapper dasar ini.
  final Widget child;

  /// Konstruktor utama dari komponen ScreenWrapper.
  const ScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: child,
      ),
    );
  }
}
