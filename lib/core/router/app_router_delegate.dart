import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/router/app_custom_transition_page.dart';
import 'package:flutter_setup_riverpod/core/router/app_route.dart';
import 'package:flutter_setup_riverpod/core/router/app_route_state.dart';

class AppRouterDelegate extends RouterDelegate<AppRouteState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRouteState> {
  final GlobalKey<NavigatorState> _navigatorKey;
  final List<AppRoute> _routes;
  final Listenable? refreshListenable;

  final List<Page<dynamic>> _pages = [];

  AppRouterDelegate({
    required GlobalKey<NavigatorState> navigatorKey,
    required List<AppRoute> routes,
    this.refreshListenable,
  }) : _navigatorKey = navigatorKey,
       _routes = routes {
    refreshListenable?.addListener(notifyListeners);
    if (_pages.isEmpty) {
      _setPath('/');
    }
  }

  @override
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  @override
  AppRouteState get currentConfiguration =>
      AppRouteState.fromPath(_pages.isEmpty ? '/' : _pages.last.name ?? '/');

  @override
  void dispose() {
    refreshListenable?.removeListener(notifyListeners);
    super.dispose();
  }

  // --- Auto Route / Flutter Nav 2.0 Style API ---

  /// Push a new route on top of the stack
  void push(String path, {Map<String, dynamic>? extra}) {
    _setPath(path, extra: extra, replace: false);
  }

  /// Replaces the current top route
  void replace(String path, {Map<String, dynamic>? extra}) {
    _setPath(path, extra: extra, replace: true);
  }

  /// Clears the stack and pushes the targeted route (sama dengan go Router atau replaceAll auto_route).
  void replaceAll(String path, {Map<String, dynamic>? extra}) {
    _pages.clear();
    _setPath(path, extra: extra, replace: false);
  }

  /// Pushes a new route and removes routes below it until the predicate returns true.
  void pushAndRemoveUntil(
    String path,
    bool Function(Page<dynamic> page) predicate, {
    Map<String, dynamic>? extra,
  }) {
    while (_pages.isNotEmpty && !predicate(_pages.last)) {
      _pages.removeLast();
    }
    _setPath(path, extra: extra, replace: false);
  }

  /// Returns true if the navigator can pop top most route.
  bool canPop() => _pages.length > 1;

  /// Safely pops the topmost route.
  void pop() {
    if (canPop()) {
      _pages.removeLast();
      notifyListeners();
    }
  }

  /// Pops the topmost route if possible, returning true if successful.
  bool maybePop() {
    if (canPop()) {
      pop();
      return true;
    }
    return false;
  }

  /// Pops routes consecutively until the predicate returns true.
  void popUntil(bool Function(Page<dynamic> page) predicate) {
    while (_pages.isNotEmpty && !predicate(_pages.last)) {
      _pages.removeLast();
    }
    notifyListeners();
  }

  /// Helper to pop until a specific route path is found.
  void popUntilPath(String path) {
    popUntil((page) => page.name != null && Uri.parse(page.name!).path == path);
  }

  // --- Core Engine ---

  Future<void> _setPath(
    String path, {
    Map<String, dynamic>? extra,
    bool replace = false,
  }) async {
    final uri = Uri.parse(path);
    final routeMatch = _matchRoute(uri.path);
    final routeState = AppRouteState.fromUri(uri, extra: extra);

    if (routeMatch != null) {
      if (routeMatch.redirect != null) {
        final redirectPath = await routeMatch.redirect!(routeState);
        if (redirectPath != null && redirectPath != path) {
          return _setPath(redirectPath, extra: extra, replace: replace);
        }
      }

      final pageKey = ValueKey(
        '${routeMatch.name ?? uri.path}_${DateTime.now().millisecondsSinceEpoch}',
      );
      Page<dynamic> page;

      if (routeMatch.pageBuilder != null) {
        page = routeMatch.pageBuilder!(routeState);
      } else {
        final child = Builder(
          builder: (context) => routeMatch.builder!(context, routeState),
        );

        if (routeMatch.transitionsBuilder != null) {
          page = AppCustomTransitionPage<dynamic>(
            key: pageKey,
            name: uri.toString(),
            child: child,
            transitionsBuilder: routeMatch.transitionsBuilder!,
            transitionDuration: routeMatch.transitionDuration,
          );
        } else {
          page = MaterialPage<dynamic>(
            key: pageKey,
            name: uri.toString(),
            child: child,
          );
        }
      }

      if (replace && _pages.isNotEmpty) {
        _pages.removeLast();
      }
      _pages.add(page);
    } else {
      final page = const MaterialPage<dynamic>(
        key: ValueKey('404'),
        name: '/404',
        child: Scaffold(body: Center(child: Text('Route not found'))),
      );
      if (replace && _pages.isNotEmpty) {
        _pages.removeLast();
      }
      _pages.add(page);
    }
    notifyListeners();
  }

  AppRoute? _matchRoute(String path) {
    return _routes.firstWhere(
      (r) => r.path == path,
      orElse: () =>
          _routes.firstWhere((r) => r.path == '/', orElse: () => _routes.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: List.of(_pages),
      onDidRemovePage: (page) {
        if (_pages.length > 1) {
          _pages.remove(page);
          notifyListeners();
        }
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRouteState configuration) async {
    await _setPath(configuration.path, extra: configuration.extra);
  }
}
