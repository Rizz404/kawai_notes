import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

/// Field input yang dapat digunakan untuk melakukan pencarian.
class AppSearchField<T> extends StatefulWidget {
  /// Nama field form builder.
  final String name;

  /// Teks petunjuk yang dirender dalam kolom pencarian saat kosong.
  final String? hintText;

  /// Nilai string awal yang dipasang untuk field search ini.
  final String? initialValue;

  /// Callback listener ketika inputan string user diubah.
  final ValueChanged<String>? onChanged;

  /// Callback yang triggered tatkala tombol bersihkan dipencet.
  final VoidCallback? onClear;

  /// Spasi pengisi di sekeliling teks input di dalam kotak.
  final EdgeInsetsGeometry? contentPadding;

  /// Warna latar form area yang dapat dicustom.
  final Color? fillColor;

  /// Konfigurasi aktivasi field ini, dimana value false mengunci input.
  final bool enabled;

  /// Ikon yang dirender duluan di bagian pangkal kolom teks masukan.
  final Widget? prefixIcon;

  /// Merender icon x buat membersihkan query jika bernilai true.
  final bool showClearButton;

  /// Fungsi untuk menjalankan form validation rule terhadap query teks.
  final String? Function(String?)? validator;

  /// Label caption di atas input kotak search.
  final String? label;

  /// Menentukan apakah fitur autocomplete search hasil dari [onSearch] di enable.
  final bool enableAutocomplete;

  /// Future function untuk menghandle data network pada list suggest search.
  final Future<List<T>> Function(String query)? onSearch;

  /// Widget function untuk menggambar card suggestion items dari result pencarian.
  final Widget Function(BuildContext context, T item)? itemBuilder;

  /// Nilai teks asli untuk item generik bertipe `T`.
  final String Function(T item)? itemValueMapper;

  /// Teks yang akan ditampakkan sebagai display suggestion pencarian dari item.
  final String Function(T item)? itemDisplayMapper;

  /// Konverter subtitle tambahan dari entitas item list.
  final String Function(T item)? itemSubtitleMapper;

  /// Bawaan default icon yang dipajang bersama di samping daftar saran.
  final IconData? itemIcon;

  /// Hook listener pada momen spesifik item dropdown ditekan untuk select.
  final void Function(T item)? onItemSelected;

  /// Default count item untuk awal pemuatan halaman.
  final int initialItemsToShow;

  /// Jumlah data page per trigger muatan lebih banyak dari lazy scroll load.
  final int itemsPerLoadMore;

  /// Nyalakan sistem loading more otomatis jika panjang list besar dan discroll.
  final bool enableLoadMore;

  /// Tinggi maksimal constraint pop menu list suggestion yang bakal dirender.
  final double? suggestionsMaxHeight;

  /// Spasi pinggir padding area dropdown menu overlay untuk suggestion.
  final EdgeInsetsGeometry? suggestionsPadding;

  /// Waktu timer dalam milisecond untuk mendaftarkan event delay di search query callback [onDebouncedChanged].
  final int debounceMilliseconds;

  /// Versi debounce dari event perubahan teks, membatasi temanya spam panggilan.
  final ValueChanged<String>? onDebouncedChanged;

  /// Nilai string awalan pertama saat screen tampil untuk box tampilan.
  final String? initialDisplayText;

  const AppSearchField({
    super.key,
    required this.name,
    this.hintText,
    this.initialValue,
    this.onChanged,
    this.onClear,
    this.contentPadding,
    this.fillColor,
    this.enabled = true,
    this.prefixIcon,
    this.showClearButton = true,
    this.validator,
    this.label,

    this.enableAutocomplete = false,
    this.onSearch,
    this.itemBuilder,
    this.itemValueMapper,
    this.itemDisplayMapper,
    this.itemSubtitleMapper,
    this.itemIcon,
    this.onItemSelected,
    this.initialItemsToShow = 5,
    this.itemsPerLoadMore = 5,
    this.enableLoadMore = true,
    this.suggestionsMaxHeight = 300,
    this.suggestionsPadding,
    this.debounceMilliseconds = 500,
    this.onDebouncedChanged,
    this.initialDisplayText,
  }) : assert(
         !enableAutocomplete || onSearch != null,
         'onSearch is required when enableAutocomplete is true',
       );

  @override
  State<AppSearchField<T>> createState() => _AppSearchFieldState<T>();
}

class _AppSearchFieldState<T> extends State<AppSearchField<T>> {
  late GlobalKey<FormBuilderFieldState<FormBuilderTextField, String>> _fieldKey;
  bool _hasText = false;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<T> _allSuggestions = [];
  List<T> _displayedSuggestions = [];
  bool _isLoadingSuggestions = false;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _currentDisplayCount = 0;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _fieldKey =
        GlobalKey<FormBuilderFieldState<FormBuilderTextField, String>>();
    _hasText = widget.initialValue?.isNotEmpty ?? false;
    _currentDisplayCount = widget.initialItemsToShow;
    _displayText = widget.initialDisplayText;

    if (widget.enableAutocomplete) {
      _focusNode.addListener(_onFocusChanged);
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideSuggestions();
    }
  }

  void _onScroll() {
    if (!widget.enableLoadMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_displayedSuggestions.length >= _allSuggestions.length) return;

    setState(() {
      _currentDisplayCount += widget.itemsPerLoadMore;
      _displayedSuggestions = _allSuggestions
          .take(_currentDisplayCount)
          .toList();
    });
    _updateOverlay();
  }

  Future<void> _performSearch(String query) async {
    if (!widget.enableAutocomplete || widget.onSearch == null) return;
    if (query.isEmpty) {
      _hideSuggestions();
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final results = await widget.onSearch!(query);
      _allSuggestions = results;
      _currentDisplayCount = widget.initialItemsToShow;
      _displayedSuggestions = results.take(_currentDisplayCount).toList();

      if (_displayedSuggestions.isNotEmpty && _focusNode.hasFocus) {
        _showSuggestionsOverlay();
      } else {
        _hideSuggestions();
      }
    } catch (e) {
      _hideSuggestions();
    } finally {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  DateTime? _lastSearchTime;
  Timer? _debounceTimer;

  void _debounceSearch(String query) {
    _lastSearchTime = DateTime.now();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      Duration(milliseconds: widget.debounceMilliseconds),
      () {
        if (_lastSearchTime != null &&
            DateTime.now().difference(_lastSearchTime!) >=
                Duration(milliseconds: widget.debounceMilliseconds)) {
          _performSearch(query);

          widget.onDebouncedChanged?.call(query);
        }
      },
    );
  }

  void _onTextChanged(String? value) {
    final hasText = value?.isNotEmpty ?? false;
    final query = value?.trim() ?? '';

    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(value ?? '');

    if (widget.enableAutocomplete || widget.onDebouncedChanged != null) {
      _debounceSearch(query);
    }
  }

  void _clearText() {
    setState(() {
      _displayText = null;
    });
    _fieldKey.currentState?.didChange('');
    widget.onClear?.call();
    widget.onChanged?.call('');
    _hideSuggestions();
  }

  void _onItemTapped(T item) {
    final displayValue =
        widget.itemDisplayMapper?.call(item) ?? item.toString();
    final value = widget.itemValueMapper?.call(item) ?? displayValue;

    _fieldKey.currentState?.didChange(value);
    setState(() {
      _displayText = displayValue;
    });

    widget.onItemSelected?.call(item);
    widget.onChanged?.call(value);

    _hideSuggestions();
    _focusNode.unfocus();
  }

  void _showSuggestionsOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    final spaceBelow = screenHeight - offset.dy - size.height;
    final spaceAbove = offset.dy;
    final maxHeight = widget.suggestionsMaxHeight ?? 300;

    final shouldShowAbove = spaceBelow < maxHeight && spaceAbove > spaceBelow;
    final availableHeight = shouldShowAbove
        ? (spaceAbove - 8).clamp(100.0, maxHeight)
        : (spaceBelow - 8).clamp(100.0, maxHeight);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: shouldShowAbove
              ? Offset(0, -(availableHeight + 4))
              : Offset(0, size.height + 4),
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
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_isLoadingSuggestions && _displayedSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
      );
    }

    if (_displayedSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            context.l10n.appSearchFieldNoResultsFound,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.suggestionsPadding ?? const EdgeInsets.all(8),
      shrinkWrap: true,
      itemCount:
          _displayedSuggestions.length +
          (_displayedSuggestions.length < _allSuggestions.length &&
                  widget.enableLoadMore
              ? 1
              : 0),
      itemBuilder: (context, index) {
        if (index >= _displayedSuggestions.length) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(context.colors.primary),
                ),
              ),
            ),
          );
        }

        final item = _displayedSuggestions[index];
        return InkWell(
          onTap: () => _onItemTapped(item),
          borderRadius: BorderRadius.circular(8),
          child: widget.itemBuilder != null
              ? widget.itemBuilder!(context, item)
              : _buildDefaultItem(item),
        );
      },
    );
  }

  Widget _buildDefaultItem(T item) {
    final displayText = widget.itemDisplayMapper?.call(item) ?? item.toString();
    final subtitle = widget.itemSubtitleMapper?.call(item);
    final icon = widget.itemIcon ?? Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  displayText,
                  style: AppTextStyle.bodyMedium,
                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: FormBuilderTextField(
            key: _fieldKey,
            name: widget.name,
            initialValue: widget.initialValue,
            enabled: widget.enabled,
            focusNode: widget.enableAutocomplete ? _focusNode : null,
            onChanged: _onTextChanged,
            validator: widget.validator,
            valueTransformer: (value) => value?.trim(),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText ?? context.l10n.appSearchFieldHint,
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textTertiary,
              ),
              prefixIcon:
                  widget.prefixIcon ??
                  Icon(Icons.search, color: context.colors.textSecondary),
              suffixIcon: _buildSuffixIcon(),
              filled: true,
              fillColor: widget.fillColor ?? context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.primary, width: 2),
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: context.textTheme.bodyMedium,
          ),
        ),
        if (_displayText != null && widget.enableAutocomplete) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: context.colors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    _displayText!,
                    style: AppTextStyle.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _displayText = null;
                    });
                    _fieldKey.currentState?.didChange('');
                    widget.onChanged?.call('');
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isLoadingSuggestions && widget.enableAutocomplete) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(context.colors.primary),
          ),
        ),
      );
    }

    if (widget.showClearButton && _hasText) {
      return IconButton(
        icon: Icon(Icons.clear, color: context.colors.textSecondary),
        onPressed: widget.enabled ? _clearText : null,
        tooltip: context.l10n.appSearchFieldClear,
      );
    }

    return null;
  }
}
