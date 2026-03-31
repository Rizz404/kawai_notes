import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/feature/notes/models/note.dart';
import 'package:flutter_setup_riverpod/feature/notes/providers/note_list_provider.dart';

class GraphViewScreen extends ConsumerWidget {
  const GraphViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listStateAsync = ref.watch(noteListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph View'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: listStateAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return const Center(child: Text('No notes available for graph.'));
          }
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 4.0,
            child: CustomPaint(
              size: const Size(2000, 2000),
              painter: _GraphPainter(notes: state.items, context: context),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<Note> notes;
  final BuildContext context;

  _GraphPainter({required this.notes, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    // Basic force-directed / circle layout
    if (notes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        min(size.width, size.height) * 0.3; // 30% of canvas as placement radius

    final nodePositions = <String, Offset>{};

    // Calculate node positions around a circle
    final angleStep = 2 * pi / notes.length;
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final angle = i * angleStep;
      nodePositions[note.title] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    }

    final edgePaint = Paint()
      ..color = context.colors.border
      ..strokeWidth = 2.0;

    final nodePaint = Paint()
      ..color = context.colorScheme.primary
      ..style = PaintingStyle.fill;

    // Draw edges for explicit links
    for (final note in notes) {
      final fromPos = nodePositions[note.title];
      if (fromPos == null) continue;

      for (final link in note.links) {
        // Link string matches another note's title
        final toPos = nodePositions[link];
        if (toPos != null) {
          canvas.drawLine(fromPos, toPos, edgePaint);
        }
      }
    }

    // Draw nodes and text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final note in notes) {
      final pos = nodePositions[note.title];
      if (pos == null) continue;

      canvas.drawCircle(pos, 10, nodePaint);

      textPainter.text = TextSpan(
        text: note.title,
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurface,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy + 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.notes != notes;
  }
}
