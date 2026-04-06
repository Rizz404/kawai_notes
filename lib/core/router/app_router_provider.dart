import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/router/app_route.dart';
import 'package:flutter_setup_riverpod/core/router/app_route_parser.dart';
import 'package:flutter_setup_riverpod/core/router/app_router_delegate.dart';
import 'package:flutter_setup_riverpod/core/router/app_transitions.dart';
import 'package:flutter_setup_riverpod/core/router/router_observer.dart';
import 'package:flutter_setup_riverpod/core/router/router_refresh_listenable.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/graph_view_screen.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/hidden_notes_screen.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/home_screen.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/note_editor_screen.dart';
import 'package:flutter_setup_riverpod/feature/settings/screens/other_screen.dart';
import 'package:flutter_setup_riverpod/feature/settings/screens/backup_screen.dart';
import 'package:flutter_setup_riverpod/feature/tasks/screens/task_editor_screen.dart';
import 'package:flutter_setup_riverpod/feature/tasks/screens/tasks_screen.dart';

import 'package:flutter_setup_riverpod/shared/widgets/app_shell.dart';

// Example route dummy. User should replace this.
final routerRoutesProvider = Provider<List<AppRouteBase>>((ref) {
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
      builder: (context, state) => const HiddenNotesScreen(),
      transitionsBuilder: AppTransitions.slideFromRight,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/note-editor',
      name: 'note_editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NoteEditorScreen(
          noteId: extra?['id'] as int?,
          initialTitle: extra?['title'] as String?,
        );
      },
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
  return AppRouterDelegate(
    navigatorKey: GlobalKey<NavigatorState>(),
    routes: routes,
    refreshListenable: refreshListenable,
  );
});

final routeParserProvider = Provider<AppRouteParser>((ref) {
  return const AppRouteParser();
});

final routerObserverProvider = Provider<AppRouterObserver>((ref) {
  return AppRouterObserver();
});
