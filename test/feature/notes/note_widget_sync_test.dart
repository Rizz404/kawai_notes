import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/notes/services/note_widget_service.dart';
import 'package:kawai_notes/feature/other/providers/trash_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

/// F5: home-screen widgets must follow note edits/hide/delete and never
/// show hidden-note content. Only the home_widget platform channel is faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ObjectBoxTestStore testStore;
  late NoteRepository notes;
  late ProviderContainer container;
  late Map<String, Object?> widgetData;
  late int updateCalls;
  const widgetId = 7;

  setUp(() async {
    widgetData = {};
    updateCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          final args = (call.arguments as Map?) ?? {};
          switch (call.method) {
            case 'saveWidgetData':
              widgetData[args['id'] as String] = args['data'];
              return true;
            case 'updateWidget':
              updateCalls++;
              return true;
            case 'getWidgetData':
              return widgetData[args['id']] ?? args['defaultValue'];
          }
          return null;
        });

    testStore = await ObjectBoxTestStore.open();
    final enc = MockEncryptionService();
    when(
      () => enc.encrypt(any()),
    ).thenAnswer((i) async => 'enc:${i.positionalArguments[0]}');
    when(() => enc.decrypt(any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as String).replaceFirst('enc:', ''),
    );
    notes = NoteRepository(
      testStore.service,
      MockNoteFileService(),
      enc,
      isHiddenUnlocked: () => true,
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(notes),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  Future<int> pinToWidget(String title, String content) async {
    final n = await notes.saveNote(title: title, content: content);
    await NoteWidgetService.saveWidget(
      prefs: container.read(sharedPreferencesProvider),
      widgetId: widgetId,
      note: n,
      contentPreview: content,
    );
    updateCalls = 0;
    return n.id;
  }

  test('editing a note refreshes the widget showing it', () async {
    final id = await pinToWidget('Old', 'old body');
    final p = noteDetailNotifierProvider(id);
    final sub = container.listen(p, (_, _) {});
    await container.read(p.future);
    await container.read(p.notifier).saveNote(title: 'New', content: 'new body');
    sub.close();

    expect(widgetData['widget_note_title_$widgetId'], 'New');
    expect(widgetData['widget_note_content_$widgetId'], 'new body');
    expect(updateCalls, greaterThan(0));
  });

  test('hiding a widget note redacts title and content', () async {
    final id = await pinToWidget('Diary', 'secret body');
    await container.read(noteListNotifierProvider.future);
    await container.read(noteListNotifierProvider.notifier).hideNotes([id]);

    expect(widgetData['widget_note_title_$widgetId'], isNot('Diary'));
    expect(
      widgetData['widget_note_content_$widgetId'].toString(),
      isNot(contains('secret body')),
    );
    expect(updateCalls, greaterThan(0));
  });

  test('trashing a widget note stops showing its content', () async {
    final id = await pinToWidget('Gone', 'bye');
    await container.read(noteListNotifierProvider.future);
    await container.read(noteListNotifierProvider.notifier).deleteNote(id);

    expect(widgetData['widget_note_title_$widgetId'], isNot('Gone'));
    expect(widgetData['widget_note_content_$widgetId'], isNot('bye'));
    expect(updateCalls, greaterThan(0));
  });

  test('permanently deleting a widget note resets it to placeholder', () async {
    final id = await pinToWidget('Gone', 'bye');
    await notes.deleteNote(id);
    final sub = container.listen(trashListNotifierProvider, (_, _) {});
    await container.read(trashListNotifierProvider.future);
    await container
        .read(trashListNotifierProvider.notifier)
        .deletePermanently(id);
    sub.close();

    expect(widgetData['widget_note_id_$widgetId'], -1);
    expect(widgetData['widget_note_title_$widgetId'], isNull);
    expect(widgetData['widget_note_content_$widgetId'], isNull);
  });

  test('the startup 30-day trash purge resets widgets of purged notes',
      () async {
    final old = await pinToWidget('Old', 'bye');
    final n = notes.getNote(old)!
      ..isDeleted = true
      ..updatedAt = DateTime.now().subtract(const Duration(days: 31));
    testStore.service.store.box<Note>().put(n);
    final keep = await notes.saveNote(title: 'Keep', content: 'k');
    await NoteWidgetService.saveWidget(
      prefs: container.read(sharedPreferencesProvider),
      widgetId: 8,
      note: keep,
      contentPreview: 'k',
    );

    final purged = await notes.cleanUpTrashNotes(days: 30);
    await NoteWidgetService.clearWidgetsForNotes(
      prefs: container.read(sharedPreferencesProvider),
      noteIds: purged,
    );

    expect(purged, [old]);
    expect(notes.getNote(old), isNull);
    expect(widgetData['widget_note_id_$widgetId'], -1);
    expect(widgetData['widget_note_title_$widgetId'], isNull);
    expect(widgetData['widget_note_title_8'], 'Keep', reason: 'untouched');
  });

  test('restoring from trash brings the widget content back', () async {
    final id = await pinToWidget('Back', 'again');
    await container.read(noteListNotifierProvider.future);
    await container.read(noteListNotifierProvider.notifier).deleteNote(id);
    final sub = container.listen(trashListNotifierProvider, (_, _) {});
    await container.read(trashListNotifierProvider.future);
    await container.read(trashListNotifierProvider.notifier).restoreNote(id);
    sub.close();

    expect(widgetData['widget_note_title_$widgetId'], 'Back');
    expect(widgetData['widget_note_content_$widgetId'], 'again');
  });

  test('saveWidget never writes hidden-note content', () async {
    final n = await notes.saveNote(
      title: 'Private',
      content: 'plain secret',
      isHidden: true,
    );
    await NoteWidgetService.saveWidget(
      prefs: container.read(sharedPreferencesProvider),
      widgetId: widgetId,
      note: n,
      contentPreview: 'plain secret',
    );
    expect(widgetData['widget_note_title_$widgetId'], isNot('Private'));
    expect(
      widgetData['widget_note_content_$widgetId'].toString(),
      isNot(contains('plain secret')),
    );
  });

  test('unhiding brings real content back to the widget', () async {
    final n = await notes.saveNote(title: 'H', content: 'body', isHidden: true);
    await NoteWidgetService.saveWidget(
      prefs: container.read(sharedPreferencesProvider),
      widgetId: widgetId,
      note: n,
      contentPreview: '',
    );
    await container.read(hiddenNoteListNotifierProvider.future);
    await container
        .read(hiddenNoteListNotifierProvider.notifier)
        .unhideNotes([n.id]);
    expect(widgetData['widget_note_title_$widgetId'], 'H');
    expect(widgetData['widget_note_content_$widgetId'], 'body');
  });
}
