import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Bottom sheet yang menampilkan opsi daftar item.
class AppListOptionsBottomSheet extends StatelessWidget {
  /// Callback yang dipanggil saat membuat item baru.
  final VoidCallback? onCreate;

  /// Callback yang dipanggil saat memilih banyak item.
  final VoidCallback onSelectMany;

  /// Builder untuk widget filter dan sort.
  final Widget Function() filterSortWidgetBuilder;

  /// Builder opsional untuk export widget.
  final Widget Function()? exportWidgetBuilder;

  /// Judul untuk aksi create.
  final String? createTitle;

  /// Sub-judul untuk aksi create.
  final String? createSubtitle;

  /// Judul untuk aksi select banyak item.
  final String? selectManyTitle;

  /// Sub-judul untuk aksi select banyak item.
  final String? selectManySubtitle;

  /// Judul untuk aksi filter dan sort.
  final String? filterSortTitle;

  /// Sub-judul untuk aksi filter dan sort.
  final String? filterSortSubtitle;

  /// Judul untuk aksi export.
  final String? exportTitle;

  /// Sub-judul untuk aksi export.
  final String? exportSubtitle;

  const AppListOptionsBottomSheet({
    super.key,
    this.onCreate,
    required this.onSelectMany,
    required this.filterSortWidgetBuilder,
    this.exportWidgetBuilder,
    this.createTitle,
    this.createSubtitle,
    this.selectManyTitle,
    this.selectManySubtitle,
    this.filterSortTitle,
    this.filterSortSubtitle,
    this.exportTitle,
    this.exportSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            AppText(
              context.l10n.sharedOptions,
              style: AppTextStyle.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 24),
            if (onCreate != null) ...[
              _OptionTile(
                icon: Icons.add_circle_outline,
                title: createTitle ?? context.l10n.sharedCreate,
                subtitle: createSubtitle ?? context.l10n.sharedAddNewItem,
                onTap: onCreate!,
              ),
              const SizedBox(height: 12),
            ],
            _OptionTile(
              icon: Icons.checklist,
              title: selectManyTitle ?? context.l10n.sharedSelectMany,
              subtitle:
                  selectManySubtitle ?? context.l10n.sharedSelectItemsToDelete,
              onTap: onSelectMany,
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.filter_list,
              title: filterSortTitle ?? context.l10n.sharedFilterAndSort,
              subtitle:
                  filterSortSubtitle ?? context.l10n.sharedCustomizeDisplay,
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: context.colors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (context) => filterSortWidgetBuilder(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (exportWidgetBuilder != null) ...[
              _OptionTile(
                icon: Icons.download,
                title: exportTitle ?? context.l10n.sharedExport,
                subtitle: exportSubtitle ?? context.l10n.sharedExportDataToFile,
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.colors.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (context) => exportWidgetBuilder!(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style: AppTextStyle.bodyLarge,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    subtitle,
                    style: AppTextStyle.bodySmall,
                    color: context.colors.textSecondary,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
