import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/notes/screens/note_editor_screen.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  testWidgets('editor for an undecryptable hidden note is locked read-only', (
    tester,
  ) async {
    late ObjectBoxTestStore testStore;
    late NoteRepository repository;
    late int noteId;
    final enc = MockEncryptionService();
    when(() => enc.encrypt(any())).thenAnswer(
      (i) async => 'enc:${i.positionalArguments[0]}',
    );
    await tester.runAsync(() async {
      testStore = await ObjectBoxTestStore.open();
      repository = NoteRepository(
        testStore.service,
        MockNoteFileService(),
        enc,
        isHiddenUnlocked: () => true,
      );
      noteId = (await repository.saveNote(
        title: 'Locked',
        content: 'secret',
        isHidden: true,
      )).id;
    });
    addTearDown(testStore.close);
    when(() => enc.decrypt(any())).thenThrow(const DecryptionException());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [noteRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: NoteEditorScreen(noteId: noteId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_decrypt_failed')), findsOneWidget);
    expect(find.byType(FormBuilder), findsNothing);
    expect(find.byIcon(Icons.palette_outlined), findsNothing);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(repository.getNote(noteId)!.content, 'enc:secret');
  });
}
