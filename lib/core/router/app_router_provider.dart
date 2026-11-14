import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_route_parser.dart';
import 'package:kawai_notes/core/router/app_route_state.dart';
import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_transitions.dart';
import 'package:kawai_notes/core/router/router_observer.dart';
import 'package:kawai_notes/core/router/router_refresh_listenable.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/auth/screens/auth_screen.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/notes/screens/graph_view_screen.dart';
import 'package:kawai_notes/feature/notes/screens/hidden_notes_auth_challenge_screen.dart';
import 'package:kawai_notes/feature/notes/screens/hidden_notes_screen.dart';
import 'package:kawai_notes/feature/notes/screens/home_screen.dart';
import 'package:kawai_notes/feature/notes/screens/note_editor_screen.dart';
import 'package:kawai_notes/feature/notes/screens/widget_config_screen.dart';
import 'package:kawai_notes/feature/other/screens/backup_screen.dart';
import 'package:kawai_notes/feature/other/screens/hidden_notes_auth_screen.dart';
import 'package:kawai_notes/feature/other/screens/other_screen.dart';
import 'package:kawai_notes/feature/other/screens/trash_screen.dart';
import 'package:kawai_notes/feature/tasks/screens/task_editor_screen.dart';
import 'package:kawai_notes/feature/tasks/screens/tasks_screen.dart';
import 'package:kawai_notes/shared/widgets/app_shell.dart';

const hiddenNotesChallengePath = '/hidden-notes-challenge';

/// Note id for the editor route, from `extra` or a validated `?id=` query.
int? _editorNoteId(AppRouteState state) {
  final fromExtra = state.extra['id'];
  if (fromExtra is int) return fromExtra;
  final raw = state.queryParams['id'];
  if (raw == null || !RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(raw)) {
    return null;
  }
  return int.tryParse(raw);
}

// Example route dummy. User should replace this.
final routerRoutesProvider = Provider<List<AppRouteBase>>((ref) {
  // * Hidden-notes routes require an unlocked session; otherwise the user is
  // * sent to the challenge, which resumes the original route on success.
  String? requireHiddenUnlock(AppRouteState state) {
    if (ref.read(hiddenNotesSessionProvider)) return null;
    return Uri(
      path: hiddenNotesChallengePath,
      queryParameters: {'next': state.uri.toString()},
    ).toString();
  }

  return [
    AppStatefulShellRoute(
      builder: (context, state, navigationShell) {
        return AppShellBody(navigationShell: navigationShell);
      },
      branches: [
        AppStatefulShellBranch(
          routes: [
            AppRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
              transitionsBuilder: AppTransitions.fadeScale,
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ],
        ),
        AppStatefulShellBranch(
          routes: [
            AppRoute(
              path: '/tasks',
              name: 'tasks',
              builder: (context, state) => const TasksScreen(),
              transitionsBuilder: AppTransitions.fadeScale,
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ],
        ),
        AppStatefulShellBranch(
          routes: [
            AppRoute(
              path: '/other',
              name: 'other',
              builder: (context, state) => const OtherScreen(),
              transitionsBuilder: AppTransitions.fadeScale,
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ],
    ),
    AppRoute(
      path: '/task-editor',
      name: 'task_editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return TaskEditorScreen(taskId: extra?['id'] as int?);
      },
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/graph-view',
      name: 'graph_view',
      builder: (context, state) => const GraphViewScreen(),
      transitionsBuilder: AppTransitions.fadeScale,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/hidden-notes',
      name: 'hidden_notes',
      redirect: requireHiddenUnlock,
      builder: (context, state) => const HiddenNotesScreen(),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/note-editor',
      name: 'note_editor',
      redirect: (state) {
        final id = _editorNoteId(state);
        final isHidden = state.extra['isHidden'] == true ||
            (id != null &&
                ref.read(noteRepositoryProvider).getNote(id)?.isHidden == true);
        if (!isHidden || ref.read(hiddenNotesSessionProvider)) return null;
        // * the challenge cannot carry `extra`; an existing note's id rides
        // * in `next` so the same editor opens after unlock
        final next = id == null
            ? '/hidden-notes'
            : Uri(
                path: '/note-editor',
                queryParameters: {'id': '$id'},
              ).toString();
        return Uri(
          path: hiddenNotesChallengePath,
          queryParameters: {'next': next},
        ).toString();
      },
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NoteEditorScreen(
          noteId: _editorNoteId(state),
          initialTitle: extra?['title'] as String?,
          isHidden: extra?['isHidden'] == true,
        );
      },
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    AppRoute(
      path: '/widget-config',
      name: 'widget_config',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NoteWidgetConfigScreen(
          widgetId: extra?['widgetId'] as int? ?? 0,
        );
      },
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: hiddenNotesChallengePath,
      name: 'hidden_notes_challenge',
      builder: (context, state) => HiddenNotesAuthChallengeScreen(
        next: state.queryParams['next'],
      ),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/hidden-notes-lock',
      name: 'hidden_notes_lock',
      redirect: (state) async {
        if (ref.read(hiddenNotesSessionProvider)) return null;
        // * with no method configured there is nothing to verify and nothing
        // * hidden to show: open the settings so the first method can be
        // * any of PIN, pattern or password. Unreadable state is challenged.
        try {
          final methods = await ref
              .read(hiddenNotesAuthServiceProvider)
              .getEnabledMethods();
          if (methods.isEmpty) return null;
        } catch (_) {}
        return requireHiddenUnlock(state);
      },
      builder: (context, state) => const HiddenNotesAuthScreen(),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/backup',
      name: 'backup',
      builder: (context, state) => const BackupScreen(),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/trash',
      name: 'trash',
      builder: (context, state) => const TrashScreen(),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];
});

final routerRefreshListenableProvider = Provider<RouterRefreshListenable>((
  ref,
) {
  return RouterRefreshListenable(ref);
});

final routerDelegateProvider = Provider<AppRouterDelegate>((ref) {
  final routes = ref.watch(routerRoutesProvider);
  final refreshListenable = ref.watch(routerRefreshListenableProvider);
  final delegate = AppRouterDelegate(
    // * the global key backs LocalizationExtension.current
    navigatorKey: navigatorKey,
    routes: routes,
    refreshListenable: refreshListenable,
  );
  // * locking the vault closes every vault page so no hidden title or
  // * content stays on screen; the challenge resumes the topmost one
  ref.listen<bool>(hiddenNotesSessionProvider, (previous, unlocked) {
    if (previous == true && !unlocked) {
      _closeVaultPages(delegate, ref.read(noteRepositoryProvider));
    }
  });
  return delegate;
});

void _closeVaultPages(AppRouterDelegate delegate, NoteRepository repository) {
  String? resumeTarget(Page<dynamic> page) {
    final name = page.name;
    if (name == null) return null;
    final path = Uri.parse(name).path;
    if (path == '/hidden-notes' || path == '/hidden-notes-lock') return path;
    if (path != '/note-editor') return null;
    final state = page.arguments is AppRouteState
        ? page.arguments! as AppRouteState
        : AppRouteState.fromPath(name);
    final id = _editorNoteId(state);
    if (id != null && repository.getNote(id)?.isHidden == true) {
      return Uri(path: '/note-editor', queryParameters: {'id': '$id'})
          .toString();
    }
    if (state.extra['isHidden'] == true) return '/hidden-notes';
    return null;
  }

  String? resume;
  for (final page in delegate.globalPages.reversed) {
    resume = resumeTarget(page);
    if (resume != null) break;
  }
  if (resume == null) return;
  delegate.removeGlobalPagesWhere((page) => resumeTarget(page) != null);
  delegate.push(
    Uri(
      path: hiddenNotesChallengePath,
      queryParameters: {'next': resume},
    ).toString(),
  );
}

final routeParserProvider = Provider<AppRouteParser>((ref) {
  return const AppRouteParser();
});

final routerObserverProvider = Provider<AppRouterObserver>((ref) {
  return AppRouterObserver();
});
