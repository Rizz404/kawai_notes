import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:kawai_notes/core/router/app_route_state.dart';

typedef RouteBuilder =
    Widget Function(BuildContext context, AppRouteState state);
typedef PageBuilder = Page<dynamic> Function(AppRouteState state);
typedef RouteRedirect = FutureOr<String?> Function(AppRouteState state);

abstract class AppRouteBase {
  final List<AppRouteBase> children;
  final String? path;
  final String? name;
  const AppRouteBase({this.children = const [], this.path, this.name});
}

class AppStatefulShellBranch {
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<AppRouteBase> routes;
  const AppStatefulShellBranch({this.navigatorKey, required this.routes});
}

typedef StatefulShellRouteBuilder =
    Widget Function(
      BuildContext context,
      AppRouteState state,
      StatefulNavigationShell navigationShell,
    );

class StatefulNavigationShell extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;
  final void Function(int) onSwitchBranch;

  const StatefulNavigationShell({
    super.key,
    required this.currentIndex,
    required this.children,
    required this.onSwitchBranch,
  });

  @override
  Widget build(BuildContext context) {
    // Disable Hero animations on inactive branches to prevent duplicate hero tag errors
    return IndexedStack(
      index: currentIndex,
      children: children.asMap().entries.map((entry) {
        return HeroMode(enabled: entry.key == currentIndex, child: entry.value);
      }).toList(),
    );
  }
}

class AppStatefulShellRoute extends AppRouteBase {
  final List<AppStatefulShellBranch> branches;
  final StatefulShellRouteBuilder builder;

  const AppStatefulShellRoute({required this.branches, required this.builder});
}

class AppRoute extends AppRouteBase {
  // ignore: overridden_fields
  @override
  final String path;
  // ignore: overridden_fields
  @override
  final String? name;

  /// The widget builder for the route.
  final RouteBuilder? builder;

  /// Optional page builder for complete control over the created Page (e.g. MaterialPage, CustomTransitionPage).
  final PageBuilder? pageBuilder;

  /// Redirect function that returns a path to redirect to, or null if no redirect is needed.
  final RouteRedirect? redirect;

  /// Custom transition builder for the route.
  final RouteTransitionsBuilder? transitionsBuilder;

  /// Duration for the transition.
  final Duration transitionDuration;

  /// Optional parent navigator key for nested routing.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  const AppRoute({
    required this.path,
    this.name,
    this.builder,
    this.pageBuilder,
    this.redirect,
    this.transitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.parentNavigatorKey,
    super.children = const [],
  }) : assert(
         builder != null || pageBuilder != null,
         'Either builder or pageBuilder must be provided.',
       );
}
