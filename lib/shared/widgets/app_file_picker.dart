import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/core/utils/toast_utils.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Form field untuk menyajikan input file picker yang mendukung multiselect dan batasan format.
class AppFilePicker extends StatelessWidget {
  /// Nama identitas (key) untuk form field tersebut.
  final String name;

  /// Label atau judul dari input pengunggah file ini.
  final String? label;

  /// Teks petunjuk tentang file apa yang seharusnya diunggah.
  final String? hintText;

  /// Menandakan apakah isian file ini wajib diisi.
  final bool isRequired;

  /// Menentukan apakah user diizinkan memilih lebih dari satu file.
  final bool allowMultiple;

  /// Daftar ektensi (format file) yang diperbolehkan untuk dipilih.
  final List<String>? allowedExtensions;

  /// Batas jumlah file maksimal jika param [allowMultiple] aktif.
  final int? maxFiles;

  /// Batasan jumlah ukuran file dihitung dalam ukuran MB.
  final int? maxSizeInMB;

  /// Fungsi validasi kustom untuk rentetan nilai [PlatformFile].
  final String? Function(List<PlatformFile>?)? validator;

  /// Nilai initial (bawaan) berupa rentetan file saat ui pertama kali dibuat.
  final List<PlatformFile>? initialFiles;

  /// Jenis spesifik dari file yang difilter saat picker terbuka.
  final FileType fileType;

  /// Fungsi callback yang dipicu setiap kali pengguna mengubah atau menghapus lampiran.
  final void Function(List<PlatformFile>)? onFilesChanged;

  const AppFilePicker({
    super.key,
    required this.name,
    this.label,
    this.hintText,
    this.isRequired = false,
    this.allowMultiple = false,
    this.allowedExtensions,
    this.maxFiles,
    this.maxSizeInMB,
    this.validator,
    this.initialFiles,
    this.fileType = FileType.any,
    this.onFilesChanged,
  });

  void _previewFile(BuildContext context, PlatformFile file) {
    showDialog<void>(
      context: context,
      barrierColor: context.colors.overlay,
      builder: (context) => _FilePreviewDialog(file: file),
    );
  }

  bool _isPreviewable(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    return [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'mp4',
      'mov',
      'avi',
    ].contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<List<PlatformFile>>(
      name: name,
      validator: validator,
      initialValue: initialFiles ?? [],
      builder: (FormFieldState<List<PlatformFile>> field) {
        final selectedFiles = field.value ?? [];

        Future<void> pickFiles() async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: fileType,
              allowMultiple: allowMultiple,
              allowedExtensions: fileType == FileType.custom ? allowedExtensions : null,
            );

            if (result != null) {
              if (!context.mounted) return;

              if (maxFiles != null && result.files.length > maxFiles!) {
                AppToast.warning(context.l10n.sharedMaxFilesAllowed(maxFiles!));
                return;
              }

              if (maxSizeInMB != null) {
                for (final file in result.files) {
                  if (file.size > (maxSizeInMB! * 1024 * 1024)) {
                    AppToast.warning(context.l10n.sharedFileTooLarge(file.name, maxSizeInMB!));
                    return;
                  }
                }
              }

              List<PlatformFile> newFiles;
              if (allowMultiple) {
                newFiles = [...selectedFiles, ...result.files];
              } else {
                newFiles = result.files;
              }

              field.didChange(newFiles);
              onFilesChanged?.call(newFiles);
              logData('Files selected: ${newFiles.length}');
            }
          } catch (e, s) {
            logError('Error picking files', e, s);
            if (context.mounted) {
              AppToast.error(context.l10n.sharedFailedToPickFiles);
            }
          }
        }

        void removeFile(int index) {
          final newFiles = List<PlatformFile>.from(selectedFiles);
          newFiles.removeAt(index);
          field.didChange(newFiles);
          onFilesChanged?.call(newFiles);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Row(
                children: [
                  AppText(
                    label!,
                    style: AppTextStyle.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                  if (isRequired)
                    AppText(
                      ' *',
                      color: context.semantic.error,
                      style: AppTextStyle.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            InkWell(
              onTap: pickFiles,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError ? context.semantic.error : context.colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.upload_file_outlined,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppText(
                        hintText ?? context.l10n.sharedChooseFiles,
                        style: AppTextStyle.bodyMedium,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    Icon(
                      Icons.add_circle_outline,
                      color: context.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...selectedFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return _FileItem(
                  file: file,
                  onRemove: () => removeFile(index),
                  onPreview: _isPreviewable(file) ? () => _previewFile(context, file) : null,
                );
              }),
            ],
            if (field.hasError) ...[
              const SizedBox(height: 8),
              AppText(
                field.errorText ?? '',
                style: AppTextStyle.bodySmall,
                color: context.semantic.error,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FileItem extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;
  final VoidCallback? onPreview;

  const _FileItem({required this.file, required this.onRemove, this.onPreview});

  String _getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get _isImage {
    final extension = file.extension?.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildFileThumbnail(BuildContext context) {
    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: kIsWeb
              ? (file.bytes != null
                    ? Image.memory(
                        file.bytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackIcon(context),
                      )
                    : _buildFallbackIcon(context))
              : (file.path != null
                    ? Image.file(
                        File(file.path!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackIcon(context),
                      )
                    : _buildFallbackIcon(context)),
        ),
      );
    }

    return _buildFallbackIcon(context);
  }

  Widget _buildFallbackIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getFileIcon(file.extension),
        color: context.colorScheme.primary,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          _buildFileThumbnail(context),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  file.name,
                  style: AppTextStyle.bodyMedium,
                  fontWeight: FontWeight.w500,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                AppText(
                  _getFileSize(file.size),
                  style: AppTextStyle.bodySmall,
                  color: context.colors.textSecondary,
                ),
              ],
            ),
          ),
          if (onPreview != null) ...[
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              onPressed: onPreview,
              iconSize: 20,
              color: context.colorScheme.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onRemove,
            iconSize: 20,
            color: context.semantic.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _FilePreviewDialog extends StatelessWidget {
  final PlatformFile file;

  const _FilePreviewDialog({required this.file});

  bool _isImage() {
    final extension = file.extension?.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  bool _isVideo() {
    final extension = file.extension?.toLowerCase();
    return ['mp4', 'mov', 'avi'].contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Center(child: _buildPreviewContent(context)),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: Icon(Icons.close, color: context.colors.textOnPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (_isImage()) {
      if (kIsWeb) {
        return file.bytes != null
            ? Image.memory(file.bytes!, fit: BoxFit.contain)
            : AppText(context.l10n.sharedUnableToPreviewImage);
      } else {
        return file.path != null
            ? Image.file(File(file.path!), fit: BoxFit.contain)
            : AppText(context.l10n.sharedUnableToPreviewImage);
      }
    } else if (_isVideo()) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_file, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          AppText(
            context.l10n.sharedVideoPreviewNotImplemented,
            style: AppTextStyle.bodyMedium,
          ),
        ],
      );
    } else {
      return AppText(context.l10n.sharedPreviewNotAvailable);
    }
  }
}
