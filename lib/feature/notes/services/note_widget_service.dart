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

  /// Simpan data catatan untuk sebuah widget dan trigger pembaruan tampilan.
  static Future<void> saveWidget({
    required SharedPreferences prefs,
    required int widgetId,
    required Note note,
    required String contentPreview,
  }) async {
    final title = note.title.isEmpty ? 'Tanpa judul' : note.title;
    final preview = contentPreview.length > 300
        ? '${contentPreview.substring(0, 300)}...'
        : contentPreview;

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

  /// Update semua widget yang menampilkan [noteId] dengan konten terbaru.
  /// Dipanggil setelah note disimpan di editor.
  static Future<void> refreshWidgetsForNote({
    required SharedPreferences prefs,
    required int noteId,
    required String title,
    required String contentPreview,
  }) async {
    final displayTitle = title.isEmpty ? 'Tanpa judul' : title;
    final preview = contentPreview.length > 300
        ? '${contentPreview.substring(0, 300)}...'
        : contentPreview;

    bool hasUpdated = false;
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (!key.startsWith(_trackingPrefix)) continue;
      final storedNoteId = prefs.getInt(key);
      if (storedNoteId != noteId) continue;

      final widgetIdStr = key.replaceFirst(_trackingPrefix, '');
      final widgetId = int.tryParse(widgetIdStr);
      if (widgetId == null) continue;

      await HomeWidget.saveWidgetData('widget_note_title_$widgetId', displayTitle);
      await HomeWidget.saveWidgetData('widget_note_content_$widgetId', preview);
      hasUpdated = true;
    }

    if (hasUpdated) {
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
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
