import 'package:flutter/material.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class PinEntryWidget extends StatefulWidget {
  final void Function(String pin) onPinComplete;
  final int pinLength;
  final String? errorMessage;

  const PinEntryWidget({
    super.key,
    required this.onPinComplete,
    this.pinLength = 4,
    this.errorMessage,
  });

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  String _pin = '';

  void _onDigit(String digit) {
    if (_pin.length >= widget.pinLength) return;
    final next = _pin + digit;
    setState(() => _pin = next);
    if (next.length == widget.pinLength) {
      widget.onPinComplete(next);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorMessage != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (i) {
            final filled = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? (hasError
                        ? context.colorScheme.error
                        : context.colorScheme.primary)
                    : null,
                border: Border.all(
                  color: hasError
                      ? context.colorScheme.error
                      : context.colorScheme.outline,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          AppText(
            widget.errorMessage!,
            color: context.colorScheme.error,
            style: AppTextStyle.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        ...['123', '456', '789'].map(
          (row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.split('').map(_buildKey).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 80),
              _buildKey('0'),
              SizedBox(
                width: 80,
                height: 64,
                child: IconButton(
                  onPressed: _onBackspace,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        style: TextButton.styleFrom(shape: const CircleBorder()),
        onPressed: () => _onDigit(digit),
        child: AppText(digit, style: AppTextStyle.titleMedium),
      ),
    );
  }
}
