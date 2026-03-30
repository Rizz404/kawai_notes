import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loader_overlay/loader_overlay.dart';

/// Widget wrapper untuk menampilkan overlay loading animation di atas komponen lain.
class AppLoaderOverlay extends StatelessWidget {
  /// Widget yang akan dibungkus oleh overlay loader.
  final Widget child;

  /// Warna kustom untuk layer overlay, opsional.
  final Color? overlayColor;

  /// Tingkat transparansi dari layer overlay, opsional.
  final double? overlayOpacity;

  /// Konstruktor utama dari komponen AppLoaderOverlay.
  const AppLoaderOverlay({
    super.key,
    required this.child,
    this.overlayColor,
    this.overlayOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: (overlayColor ?? context.colors.overlay).withValues(
        alpha: overlayOpacity ?? 0.6,
      ),
      overlayWidgetBuilder: (progress) => Center(
        child: SpinKitThreeBounce(color: context.colorScheme.primary, size: 50),
      ),
      child: child,
    );
  }
}
