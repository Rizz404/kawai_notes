import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/screens/graph_view_screen.dart';

Note _n(int id, String title, {List<String> links = const []}) =>
    Note(id: id, ulid: 'u$id', title: title, contentPath: '', links: links);

/// F13/MINOR-2: graph nodes are keyed by note id, so notes sharing a title
/// stay separate nodes.
void main() {
  test('notes with the same title get distinct nodes', () {
    final layout = computeGraphLayout([
      _n(1, 'Same'),
      _n(2, 'Same'),
      _n(3, 'Other'),
    ], const Size(1000, 1000));

    expect(layout.positions.keys, unorderedEquals([1, 2, 3]));
    expect(layout.positions[1], isNot(layout.positions[2]));
  });

  test('links by title connect to every matching note', () {
    final layout = computeGraphLayout([
      _n(1, 'A', links: ['B']),
      _n(2, 'B'),
      _n(3, 'B'),
    ], const Size(1000, 1000));

    expect(layout.edges, unorderedEquals([(1, 2), (1, 3)]));
  });
}
