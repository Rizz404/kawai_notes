import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:kawai_notes/feature/notes/widgets/hidden_notes_auth_body.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class HiddenNotesAuthChallengeScreen extends ConsumerWidget {
  /// Route to open after a successful challenge. Only hidden-notes routes
  /// and the editor for a specific note id are accepted; anything else
  /// falls back to the hidden notes list.
  final String? next;

  const HiddenNotesAuthChallengeScreen({super.key, this.next});

  static const _fallback = '/hidden-notes';
  static const _allowedNext = {'/hidden-notes', '/hidden-notes-lock'};
  static final _idPattern = RegExp(r'^[1-9][0-9]{0,15}$');

  /// Validates a `next` target, returning the fallback when it is not an
  /// allowed relative vault route.
  static String resolveNext(String? next) {
    final uri = Uri.tryParse(next ?? '');
    if (uri == null || uri.hasScheme || uri.hasAuthority) return _fallback;
    if (_allowedNext.contains(uri.path) && !uri.hasQuery) return next!;
    if (uri.path == '/note-editor' &&
        uri.queryParameters.length == 1 &&
        _idPattern.hasMatch(uri.queryParameters['id'] ?? '')) {
      return next!;
    }
    return _fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = resolveNext(next);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const AppText('Verify Identity'),
      ),
      body: HiddenNotesAuthBody(
        onSuccess: () {
          ref.read(hiddenNotesSessionProvider.notifier).unlock();
          context.replace(target);
        },
        onCancel: () => context.pop(),
      ),
    );
  }
}
