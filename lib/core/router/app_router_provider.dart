import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/router/app_route.dart';
import 'package:flutter_setup_riverpod/core/router/app_route_parser.dart';
import 'package:flutter_setup_riverpod/core/router/app_router_delegate.dart';
import 'package:flutter_setup_riverpod/core/router/app_transitions.dart';
import 'package:flutter_setup_riverpod/core/router/router_observer.dart';
import 'package:flutter_setup_riverpod/core/router/router_refresh_listenable.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/home_screen.dart';
import 'package:flutter_setup_riverpod/feature/notes/screens/note_editor_screen.dart';
import 'package:flutter_setup_riverpod/feature/tasks/screens/tasks_screen.dart';
import 'package:flutter_setup_riverpod/feature/tasks/screens/task_editor_screen.dart';

// Example route dummy. User should replace this.
final routerRoutesProvider = Provider<List<AppRoute>>((ref) {
  return [
    AppRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
      // Menerapkan custom transition fadeScale dari app_transitions.dart
      transitionsBuilder: AppTransitions.fadeScale,
      transitionDuration: const Duration(milliseconds: 300),
    ),
    AppRoute(
      path: '/tasks',
      name: 'tasks',
      builder: (context, state) => const TasksScreen(),
      transitionsBuilder: AppTransitions.fadeScale,
      transitionDuration: const Duration(milliseconds: 300),
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
      path: '/note-editor',
      name: 'note_editor',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NoteEditorScreen(
          noteId: extra?['id'] as int?,
          initialTitle: extra?['title'] as String?,
        );
      },
      // Menerapkan custom transition slideFromRight
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
