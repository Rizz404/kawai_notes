import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:flutter_setup_riverpod/core/router/app_route_state.dart';

typedef RouteBuilder =
    Widget Function(BuildContext context, AppRouteState state);
typedef PageBuilder = Page<dynamic> Function(AppRouteState state);
typedef RouteRedirect = FutureOr<String?> Function(AppRouteState state);

class AppRoute {
  final String path;
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

  /// Child routes.
  final List<AppRoute> children;

  const AppRoute({
    required this.path,
    this.name,
    this.builder,
    this.pageBuilder,
    this.redirect,
    this.transitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.parentNavigatorKey,
    this.children = const [],
  }) : assert(
         builder != null || pageBuilder != null,
         'Either builder or pageBuilder must be provided.',
       );
}
