import 'package:flutter/material.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class PatternEntryWidget extends StatefulWidget {
  final void Function(List<int> pattern) onPatternComplete;
  final int minLength;
  final String? errorMessage;
  final double size;

  const PatternEntryWidget({
    super.key,
    required this.onPatternComplete,
    this.minLength = 4,
    this.errorMessage,
    this.size = 280,
  });

  @override
  State<PatternEntryWidget> createState() => _PatternEntryWidgetState();
}

class _PatternEntryWidgetState extends State<PatternEntryWidget> {
  final List<int> _pattern = [];
  Offset? _currentDrag;
  bool _complete = false;

  List<Offset> get _nodePositions {
    final cell = widget.size / 3;
    return List.generate(
      9,
      (i) => Offset(cell * (i % 3 + 0.5), cell * (i ~/ 3 + 0.5)),
    );
  }

  int? _nodeAt(Offset pos) {
    const hitRadius = 28.0;
    final nodes = _nodePositions;
    for (int i = 0; i < 9; i++) {
      if ((nodes[i] - pos).distance <= hitRadius) return i;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    if (_complete) {
      setState(() {
        _pattern.clear();
        _complete = false;
        _currentDrag = null;
      });
    }
    final node = _nodeAt(d.localPosition);
    if (node != null) {
      setState(() {
        _pattern
          ..clear()
          ..add(node);
        _currentDrag = d.localPosition;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentDrag = d.localPosition);
    final node = _nodeAt(d.localPosition);
    if (node != null && !_pattern.contains(node)) {
      setState(() => _pattern.add(node));
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_pattern.length >= widget.minLength) {
      setState(() {
        _complete = true;
        _currentDrag = null;
      });
      widget.onPatternComplete(List.from(_pattern));
    } else {
      setState(() {
        _pattern.clear();
        _currentDrag = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorMessage != null;
    final activeColor =
        hasError ? context.colorScheme.error : context.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _PatternPainter(
                pattern: _pattern,
                currentDrag: _currentDrag,
                nodePositions: _nodePositions,
                activeColor: activeColor,
                outlineColor: context.colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          AppText(
            widget.errorMessage!,
            color: context.colorScheme.error,
            style: AppTextStyle.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Offset? currentDrag;
  final List<Offset> nodePositions;
  final Color activeColor;
  final Color outlineColor;

  const _PatternPainter({
    required this.pattern,
    required this.currentDrag,
    required this.nodePositions,
    required this.activeColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < pattern.length - 1; i++) {
      canvas.drawLine(
        nodePositions[pattern[i]],
        nodePositions[pattern[i + 1]],
        linePaint,
      );
    }

    if (pattern.isNotEmpty && currentDrag != null) {
      canvas.drawLine(nodePositions[pattern.last], currentDrag!, linePaint);
    }

    for (int i = 0; i < 9; i++) {
      final pos = nodePositions[i];
      final isSelected = pattern.contains(i);
      final color = isSelected ? activeColor : outlineColor;

      canvas.drawCircle(
        pos,
        20,
        Paint()
          ..color = color.withValues(alpha: isSelected ? 0.15 : 0.08)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        20,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      if (isSelected) {
        canvas.drawCircle(
          pos,
          6,
          Paint()
            ..color = activeColor
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern ||
      old.currentDrag != currentDrag ||
      old.activeColor != activeColor;
}
