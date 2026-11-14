import 'package:home_widget/home_widget.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mengelola data dan pembaruan widget Android untuk catatan.
///
/// Setiap instance widget diidentifikasi oleh [widgetId] unik dari Android.
/// Data disimpan di dua tempat:
///   - "HomeWidgetPlugin" SharedPreferences → dibaca langsung oleh NoteWidgetProvider.kt
///   - SharedPreferences biasa → digunakan untuk lookup "widget mana yang menampilkan noteId X"
class NoteWidgetService {
  static const String _androidWidgetName = 'NoteWidgetProvider';

  // Key prefix di SharedPreferences biasa untuk tracking pemetaan widget→note
  static const String _trackingPrefix = 'kawai_widget_note_id_';

  // Placeholder yang ditampilkan widget untuk catatan tersembunyi/terhapus,
  // agar isi catatan tidak pernah tersimpan di prefs widget.
  static const String hiddenTitle = 'Catatan tersembunyi';
  static const String deletedTitle = 'Catatan dihapus';

  static ({String title, String preview}) _displayFor(
    Note note,
    String contentPreview,
  ) {
    if (note.isHidden) return (title: hiddenTitle, preview: '');
    if (note.isDeleted) return (title: deletedTitle, preview: '');
    final title = note.title.isEmpty ? 'Tanpa judul' : note.title;
    final preview = contentPreview.length > 300
        ? '${contentPreview.substring(0, 300)}...'
        : contentPreview;
    return (title: title, preview: preview);
  }

  static List<int> _widgetIdsForNote(SharedPreferences prefs, int noteId) {
    final ids = <int>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_trackingPrefix)) continue;
      if (prefs.getInt(key) != noteId) continue;
      final widgetId = int.tryParse(key.replaceFirst(_trackingPrefix, ''));
      if (widgetId != null) ids.add(widgetId);
    }
    return ids;
  }

  /// Simpan data catatan untuk sebuah widget dan trigger pembaruan tampilan.
  static Future<void> saveWidget({
    required SharedPreferences prefs,
    required int widgetId,
    required Note note,
    required String contentPreview,
  }) async {
    final (:title, :preview) = _displayFor(note, contentPreview);

    // Simpan ke HomeWidgetPlugin agar NoteWidgetProvider.kt bisa membacanya
    await HomeWidget.saveWidgetData('widget_note_id_$widgetId', note.id);
    await HomeWidget.saveWidgetData('widget_note_title_$widgetId', title);
    await HomeWidget.saveWidgetData('widget_note_content_$widgetId', preview);

    // Simpan ke regular SharedPreferences untuk lookup auto-refresh
    await prefs.setInt('$_trackingPrefix$widgetId', note.id);

    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  /// Hapus data catatan dari sebuah widget (reset ke kondisi placeholder).
  static Future<void> clearWidget({
    required SharedPreferences prefs,
    required int widgetId,
  }) async {
    await HomeWidget.saveWidgetData('widget_note_id_$widgetId', -1);
    await HomeWidget.saveWidgetData('widget_note_title_$widgetId', null);
    await HomeWidget.saveWidgetData('widget_note_content_$widgetId', null);
    await prefs.remove('$_trackingPrefix$widgetId');
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  /// Update semua widget yang menampilkan [note] dengan konten terbaru.
  /// Catatan tersembunyi atau di tempat sampah ditampilkan sebagai placeholder.
  static Future<void> refreshWidgetsForNote({
    required SharedPreferences prefs,
    required Note note,
    required String contentPreview,
  }) async {
    final widgetIds = _widgetIdsForNote(prefs, note.id);
    if (widgetIds.isEmpty) return;

    final (:title, :preview) = _displayFor(note, contentPreview);
    for (final widgetId in widgetIds) {
      await HomeWidget.saveWidgetData('widget_note_title_$widgetId', title);
      await HomeWidget.saveWidgetData('widget_note_content_$widgetId', preview);
    }
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  /// Reset semua widget yang menampilkan [noteId] (catatan dihapus permanen).
  static Future<void> clearWidgetsForNote({
    required SharedPreferences prefs,
    required int noteId,
  }) async {
    for (final widgetId in _widgetIdsForNote(prefs, noteId)) {
      await clearWidget(prefs: prefs, widgetId: widgetId);
    }
  }

  /// Reset widget untuk setiap catatan di [noteIds] yang dihapus permanen.
  static Future<void> clearWidgetsForNotes({
    required SharedPreferences prefs,
    required Iterable<int> noteIds,
  }) async {
    for (final noteId in noteIds) {
      await clearWidgetsForNote(prefs: prefs, noteId: noteId);
    }
  }

  /// Ambil noteId yang sedang ditampilkan oleh sebuah widget.
  /// Mengembalikan null jika widget belum dikonfigurasi.
  static Future<int?> getWidgetNoteId(int widgetId) async {
    final id = await HomeWidget.getWidgetData<int>(
      'widget_note_id_$widgetId',
      defaultValue: -1,
    );
    return (id == null || id == -1) ? null : id;
  }
}
