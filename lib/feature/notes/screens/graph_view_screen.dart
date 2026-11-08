import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class GraphViewScreen extends ConsumerWidget {
  const GraphViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listStateAsync = ref.watch(noteListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppText(context.l10n.notesGraphTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: listStateAsync.when(
        data: (state) {
          if (state.items.isEmpty) {
            return Center(child: AppText(context.l10n.notesGraphEmpty));
          }
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 4.0,
            child: CustomPaint(
              size: const Size(2000, 2000),
              isComplex: true,
              willChange: false,
              painter: _GraphPainter(notes: state.items, context: context),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: AppText(context.l10n.notesError(e.toString()))),
      ),
    );
  }
}

typedef GraphLayout = ({Map<int, Offset> positions, List<(int, int)> edges});

/// Lays notes out on a circle keyed by note id, so notes that share a
/// title stay distinct. A title link connects to every note with that title.
GraphLayout computeGraphLayout(List<Note> notes, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = min(size.width, size.height) * 0.3;
  final positions = <int, Offset>{};
  final idsByTitle = <String, List<int>>{};
  final angleStep = notes.isEmpty ? 0.0 : 2 * pi / notes.length;
  for (int i = 0; i < notes.length; i++) {
    final note = notes[i];
    positions[note.id] = Offset(
      center.dx + radius * cos(i * angleStep),
      center.dy + radius * sin(i * angleStep),
    );
    (idsByTitle[note.title] ??= []).add(note.id);
  }
  final edges = <(int, int)>[];
  for (final note in notes) {
    for (final link in note.links) {
      for (final to in idsByTitle[link] ?? const <int>[]) {
        if (to != note.id) edges.add((note.id, to));
      }
    }
  }
  return (positions: positions, edges: edges);
}

class _GraphPainter extends CustomPainter {
  final List<Note> notes;
  final BuildContext context;

  _GraphPainter({required this.notes, required this.context});

  @override
  void paint(Canvas canvas, Size size) {
    // Basic force-directed / circle layout
    if (notes.isEmpty) return;

    final layout = computeGraphLayout(notes, size);
    final nodePositions = layout.positions;

    final edgePaint = Paint()
      ..color = context.colorScheme.outlineVariant
      ..strokeWidth = 2.0;

    final nodePaint = Paint()
      ..color = context.colorScheme.primary
      ..style = PaintingStyle.fill;

    // Draw edges for explicit links
    for (final (from, to) in layout.edges) {
      canvas.drawLine(nodePositions[from]!, nodePositions[to]!, edgePaint);
    }

    // Draw nodes and text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final note in notes) {
      final pos = nodePositions[note.id];
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
