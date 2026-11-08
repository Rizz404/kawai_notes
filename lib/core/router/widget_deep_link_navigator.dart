import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/services/widget_deep_link_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';

/// Opens home-screen widget links (`com.rizz.kawainotes://widget-note` and
/// `widget-config`) for cold start, background and foreground delivery.
///
/// Ids are validated and must refer to an existing, non-deleted note. The
/// editor route's own guard sends hidden notes through the vault challenge,
/// whose `next` resumes this same editor after unlock.
class WidgetDeepLinkNavigator {
  final AppRouterDelegate router;
  final Note? Function(int id) findNote;

  WidgetDeepLinkNavigator({required this.router, required this.findNote});

  static final _idPattern = RegExp(r'^[1-9][0-9]{0,15}$');

  static int? parseId(String? raw) {
    if (raw == null || !_idPattern.hasMatch(raw)) return null;
    return int.tryParse(raw);
  }

  /// Returns whether the link was accepted and navigation started.
  Future<bool> open(Uri uri) async {
    if (!WidgetDeepLinkService.isWidgetUri(uri)) return false;

    if (uri.host == 'widget-note') {
      final id = parseId(uri.queryParameters['noteId']);
      if (id == null) return false;
      final note = findNote(id);
      if (note == null || note.isDeleted) return false;
      final target = Uri(
        path: '/note-editor',
        queryParameters: {'id': '$id'},
      ).toString();
      if (_alreadyShowing(target)) return true;
      router.push(target, extra: {'id': id});
      return true;
    }

    final widgetId = parseId(uri.queryParameters['widgetId']);
    if (widgetId == null) return false;
    router.push('/widget-config', extra: {'widgetId': widgetId});
    return true;
  }

  /// A link delivered twice (initial link plus stream) must not stack a
  /// second editor or challenge for the same note.
  bool _alreadyShowing(String target) {
    final current = router.currentConfiguration.uri;
    if (current.toString() == target) return true;
    return current.path == hiddenNotesChallengePath &&
        current.queryParameters['next'] == target;
  }
}
