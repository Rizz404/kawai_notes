import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Widget yang menampilkan ilustrasi dan pesan ketika terjadi sebuah error atau state yang gagal.
class AppErrorState extends StatelessWidget {
  /// Judul utama yang mendeskripsikan error.
  final String title;

  /// Penjelasan lebih detail mengenai error yang terjadi.
  final String description;

  /// Icon yang akan ditampilkan di atas teks error.
  final IconData icon;

  /// Fungsi callback yang dipanggil jika tombol coba lagi ditekan.
  final VoidCallback? onRetry;

  /// Label teks khusus untuk tombol coba lagi.
  final String? retryButtonText;

  const AppErrorState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.semantic.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: context.semantic.error),
            ),
            const SizedBox(height: 24),
            AppText(
              title,
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            AppText(
              description,
              style: AppTextStyle.bodyMedium,
              color: context.colors.textSecondary,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText ?? context.l10n.sharedRetry),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
