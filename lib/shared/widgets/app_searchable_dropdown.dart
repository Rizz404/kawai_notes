import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Dropdown interaktif yang memungkinkan users mengetik di text box untuk memfilter daftar list [items].
class AppSearchableDropdown<T> extends StatefulWidget {
  /// Nama internal field tipe dari library flutter form builder.
  final String name;

  /// Nilai entitas opsional default sewaktu dropdown dipanggil pertama.
  final T? initialValue;

  /// Caption teks pembantu widget yang nampang di pojok alas box dropdown.
  final String? label;

  /// Saran abu abu bila tak ada nilai [T] yang nampak mengisi masukan dropdown.
  final String? hintText;

  /// Boolean jika di-set true maka input box aktif untuk modifikasi event onTap.
  final bool enabled;

  /// Cek rule dari validasi field dropdown apakah ada null/kosong dan memunculkan error message.
  final String? Function(String?)? validator;

  /// Kumpulan list list generic items yang disajikan dari backend/state ke menu popup di-scroll.
  final List<T> items;

  /// Flag penanda apabila ada data refresh yg butuh waktu, merender circular loader.
  final bool isLoading;

  /// Fungsi pengirim pencarian inputan dikala keyboard ditekan ke proses pencarian eksternal.
  final ValueChanged<String> onSearch;

  /// Event opsional ketika dropdown digeser hingga ujung list, men-trigger pagination API baru.
  final VoidCallback? onLoadMore;

  /// Apakah daftar remote api yang dituju sudah tidak memiliki index item selanjutnya buat di paginasi.
  final bool hasMore;

  /// Flag mengidentifikasi bila widget dropdown sedang menunggu [onLoadMore] api berjalan memutar spinner indicator.
  final bool isLoadingMore;

  /// Judul tampilan utama teks item list pada entitas objek generic [T] map.
  final String Function(T item) itemDisplayMapper;

  /// Ekstraktor raw value seperti id yang dipancarkan ketika validasi.
  final String Function(T item) itemValueMapper;

  /// Menampilkan baris paragraf kedua sekunder detail info list dari [item].
  final String? Function(T item)? itemSubtitleMapper;

  /// Mapper buat mengidentifikasi logo di popup list entitas jika ada di setiap index [item].
  final IconData? Function(T item)? itemIconMapper;

  /// Memberi notif kepada class pemanggil waktu item [T] ini terpilih.
  final void Function(T? item)? onChanged;

  /// Batas padding internal keliling jarak elemen input text box.
  final EdgeInsetsGeometry? contentPadding;

  /// Cat bg belakang border inputan.
  final Color? fillColor;

  /// Tambahan dekorasi pemanis icon depan widget input dropdown sebelum placehoder font/value teks.
  final Widget? prefixIcon;

  /// Konstriks tinggi box daftar dropdown di layar jika data panjang agar list dapat men-scroll isinya dengan mulus.
  final double dropdownMaxHeight;

  const AppSearchableDropdown({
    super.key,
    required this.name,
    required this.items,
    required this.isLoading,
    required this.onSearch,
    required this.itemDisplayMapper,
    required this.itemValueMapper,
    this.initialValue,
    this.label,
    this.hintText,
    this.enabled = true,
    this.validator,
    this.itemSubtitleMapper,
    this.itemIconMapper,
    this.onChanged,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.contentPadding,
    this.fillColor,
    this.prefixIcon,
    this.dropdownMaxHeight = 400,
  });

  @override
  State<AppSearchableDropdown<T>> createState() =>
      _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late GlobalKey<FormBuilderFieldState<FormBuilderField<String>, String>>
  _fieldKey;

  OverlayEntry? _overlayEntry;
  T? _selectedItem;
  Timer? _debounceTimer;
  ScrollController? _scrollController;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _fieldKey =
        GlobalKey<FormBuilderFieldState<FormBuilderField<String>, String>>();
    _selectedItem = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant AppSearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialValue != oldWidget.initialValue) {
      _selectedItem = widget.initialValue;
    }

    if (_overlayEntry != null) {
      if (widget.items != oldWidget.items ||
          widget.isLoading != oldWidget.isLoading ||
          widget.isLoadingMore != oldWidget.isLoadingMore ||
          widget.hasMore != oldWidget.hasMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _overlayEntry?.markNeedsBuild();
        });
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController?.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onSearch(query);
    });
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;

    if (_isDropdownOpen) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_isDropdownOpen) return;

    _scrollController?.dispose();
    _scrollController = ScrollController();
    _setupScrollListener();

    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isDropdownOpen = true;

    setState(() {});
  }

  void _hideDropdown() {
    if (!_isDropdownOpen) return;

    _removeOverlay();
    _searchController.clear();
    _debounceTimer?.cancel();
    _isDropdownOpen = false;

    widget.onSearch('');

    FocusScope.of(context).unfocus();

    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _setupScrollListener() {
    _scrollController?.addListener(() {
      if (_scrollController == null || !_scrollController!.hasClients) return;

      if (widget.onLoadMore != null &&
          widget.hasMore &&
          !widget.isLoadingMore) {
        final maxScroll = _scrollController!.position.maxScrollExtent;
        final currentScroll = _scrollController!.position.pixels;
        final threshold = maxScroll * 0.8;

        if (currentScroll >= threshold) {
          widget.onLoadMore!();
        }
      }
    });
  }

  void _selectItem(T item) {
    final value = widget.itemValueMapper(item);
    _fieldKey.currentState?.didChange(value);

    setState(() {
      _selectedItem = item;
    });

    widget.onChanged?.call(item);
    _hideDropdown();
  }

  void _clearSelection() {
    _fieldKey.currentState?.didChange(null);

    setState(() {
      _selectedItem = null;
    });

    widget.onChanged?.call(null);
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    final spaceBelow = screenHeight - offset.dy - size.height;
    final spaceAbove = offset.dy;
    final maxHeight = widget.dropdownMaxHeight;

    final shouldShowAbove = spaceBelow < maxHeight && spaceAbove > spaceBelow;
    final availableHeight = shouldShowAbove
        ? (spaceAbove - 8).clamp(200.0, maxHeight)
        : (spaceBelow - 8).clamp(200.0, maxHeight);

    return OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: shouldShowAbove
              ? Offset(0, -(availableHeight + 4))
              : Offset(0, size.height + 4),
          child: TapRegion(
            onTapOutside: (_) => _hideDropdown(),
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(12),
              color: context.colors.surface,
              child: Container(
                constraints: BoxConstraints(maxHeight: availableHeight),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSearchHeader(),
                    Flexible(child: _buildItemsList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: context.l10n.appSearchFieldHint,
          hintStyle: context.textTheme.bodySmall?.copyWith(
            color: context.colors.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: context.colors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          isDense: true,
          filled: true,
          fillColor: context.colors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        style: context.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildItemsList() {
    final items = widget.items;
    final isLoading = widget.isLoading;

    if (isLoading && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: AppText(
            context.l10n.appSearchFieldNoResultsFound,
            style: AppTextStyle.bodyMedium,
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    int extraItems = 0;
    if (widget.isLoadingMore) {
      extraItems = 1;
    } else if (!widget.hasMore && items.isNotEmpty) {
      extraItems = 1;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      itemCount: items.length + extraItems,
      itemBuilder: (context, index) {
        if (index == items.length && widget.isLoadingMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(context.colors.primary),
                ),
              ),
            ),
          );
        }

        if (index == items.length && !widget.hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: AppText(
                'Tidak ada data lagi',
                style: AppTextStyle.bodySmall,
                color: context.colors.textTertiary,
              ),
            ),
          );
        }

        final item = items[index];
        final isSelected =
            _selectedItem != null &&
            widget.itemValueMapper(_selectedItem as T) ==
                widget.itemValueMapper(item);

        return _buildItem(item, isSelected);
      },
    );
  }

  Widget _buildItem(T item, bool isSelected) {
    final displayText = widget.itemDisplayMapper(item);
    final subtitle = widget.itemSubtitleMapper?.call(item);
    final icon = widget.itemIconMapper?.call(item);

    return InkWell(
      onTap: () => _selectItem(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: context.colors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected
                    ? context.colors.primary
                    : context.colors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    displayText,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textPrimary,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
                      style: AppTextStyle.bodySmall,
                      color: context.colors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.colors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: FormBuilderField<String>(
        key: _fieldKey,
        name: widget.name,
        initialValue: widget.initialValue != null
            ? widget.itemValueMapper(widget.initialValue as T)
            : null,
        enabled: widget.enabled,
        validator: widget.validator,
        builder: (FormFieldState<String> field) {
          final hasError = field.hasError;
          final displayText = _selectedItem != null
              ? widget.itemDisplayMapper(_selectedItem as T)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _toggleDropdown,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText:
                        widget.hintText ?? context.l10n.appDropdownSelectOption,
                    hintStyle: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedItem != null && widget.enabled)
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                            onPressed: _clearSelection,
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        Icon(
                          _isDropdownOpen
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: widget.enabled
                              ? context.colors.textSecondary
                              : context.colors.textDisabled,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    filled: true,
                    fillColor: widget.fillColor ?? context.colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.border,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.semantic.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.semantic.error,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.colors.disabled,
                        width: 1,
                      ),
                    ),
                    contentPadding:
                        widget.contentPadding ??
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                    errorText: hasError ? field.errorText : null,
                  ),
                  child: displayText != null
                      ? AppText(
                          displayText,
                          style: AppTextStyle.bodyMedium,
                          color: widget.enabled
                              ? context.colors.textPrimary
                              : context.colors.textDisabled,
                        )
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
