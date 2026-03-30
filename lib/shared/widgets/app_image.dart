import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Enum yang mendefinisikan beberapa variabel ukuran standar dari komponen AppImage.
enum ImageSize {
  xSmall(16),
  small(24),
  medium(32),
  large(48),
  xLarge(64),
  xxLarge(96),
  xxxLarge(128),
  fullWidth(250);

  const ImageSize(this.value);
  final double value;
}

/// Enum yang mewakili dua bentuk geometri utama dari gambar yakni lingkaran dan persegi panjang.
enum ImageShape { circle, rectangle }

/// Widget wrapper khusus yang menangani gambar berbasis local file, url network, maupun static asset.
class AppImage extends StatelessWidget {
  /// Ukuran proporsional gambar yang di-resolve menjadi satuan logic pixel.
  final ImageSize size;

  /// URL tautan network yang akan dirender jika tidak null.
  final String? imageUrl;

  /// Path dari static image di dalam bundle APK jika tidak null.
  final String? assetPath;

  /// System file yang menunjuk kepada image buffer jika disediakan.
  final File? imageFile;

  /// Widget yang ditampilkan sembari menunggu network image dimuat atau sebelum load selesai.
  final Widget? placeholder;

  /// Widget fallback yang tampil seandainya error terjadi ketika mencoba render image.
  final Widget? errorWidget;

  /// Fungsi handler yang dipanggil saat user menekankan jari ke arah komponen image.
  final VoidCallback? onTap;

  /// Apakah diperbolehkan membuka dialog viewer gambar ukuran penuh di klik.
  final bool enablePreview;

  /// Kontrol visibilitas untuk batas (border) yang mengelilingi radius luar kotak gambar.
  final bool showBorder;

  /// Warna bingkai dekoratif jika show border diterapkan.
  final Color? borderColor;

  /// Ketebalan bingkai garis keliling jika [showBorder] memiliki nilai true.
  final double? borderWidth;

  /// Bentuk kliping luar yang membungkus gambar ([circle] atau [rectangle]).
  final ImageShape shape;

  /// Cara agar foto beradaptasi dengan dimensi kotaknya, standar menggunakan cover.
  final BoxFit fit;

  /// Warna di sekitar lapisan padding / background jika gambar berada di dalam kotak.
  final Color? backgroundColor;

  /// Lebar mutlak tambahan dari gambar jika tak mengandalkan nilai di enum [size].
  final double? width;
  final double? height;

  const AppImage({
    super.key,
    this.size = ImageSize.medium,
    this.imageUrl,
    this.assetPath,
    this.imageFile,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.enablePreview = false,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.shape = ImageShape.rectangle,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.width,
    this.height,
  });

  bool get _isNetworkImage =>
      imageUrl != null && Uri.tryParse(imageUrl!)?.hasScheme == true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final isFullWidthEnum = size == ImageSize.fullWidth;

    final effectiveWidth =
        width ?? (isFullWidthEnum ? double.infinity : size.value);
    final effectiveHeight = height ?? size.value;

    final borderRadius = shape == ImageShape.circle
        ? BorderRadius.circular(effectiveWidth / 2)
        : BorderRadius.circular(12);

    final effectiveBorderColor = borderColor ?? theme.colorScheme.outline;
    final effectiveBorderWidth = borderWidth ?? 1.0;

    Widget imageWidget;

    if (_isNetworkImage) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        placeholder: (context, url) => Skeletonizer(
          enabled: true,
          child: Container(
            width: effectiveWidth,
            height: effectiveHeight,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: effectiveWidth * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else if (assetPath != null) {
      imageWidget = Image.asset(
        assetPath!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: effectiveWidth * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else if (imageFile != null) {
      imageWidget = Image.file(
        imageFile!,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ??
            Icon(
              Icons.broken_image,
              size: effectiveWidth * 0.5,
              color: theme.colorScheme.error,
            ),
      );
    } else {
      imageWidget =
          placeholder ??
          Container(
            width: effectiveWidth,
            height: effectiveHeight,
            color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
          );
    }

    final containerWidth = effectiveWidth == double.infinity
        ? double.infinity
        : effectiveWidth + (showBorder ? effectiveBorderWidth * 2 : 0);

    final containerHeight =
        effectiveHeight + (showBorder ? effectiveBorderWidth * 2 : 0);

    final container = Container(
      width: containerWidth,

      height: containerHeight,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              )
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: imageWidget),
    );

    void handleTap() {
      if (onTap != null) {
        onTap!();
      } else if (enablePreview) {
        Widget? previewImage;
        if (_isNetworkImage) {
          previewImage = CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.white, size: 48),
          );
        } else if (assetPath != null) {
          previewImage = Image.asset(assetPath!, fit: BoxFit.contain);
        } else if (imageFile != null) {
          previewImage = Image.file(imageFile!, fit: BoxFit.contain);
        }

        if (previewImage != null) {
          showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.loose,
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black.withValues(alpha: 0.8),
                        child: previewImage,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: SafeArea(
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 32,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (onTap != null || enablePreview) {
      return InkWell(
        onTap: handleTap,
        borderRadius: borderRadius,
        child: container,
      );
    }

    return container;
  }
}
