import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/core/router/app_custom_transition_page.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_route_state.dart';
import 'package:kawai_notes/core/utils/toast_utils.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class AppRouterDelegate extends RouterDelegate<AppRouteState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRouteState> {
  final GlobalKey<NavigatorState> _navigatorKey;
  final List<AppRouteBase> _routes;
  final Listenable? refreshListenable;

  final List<Page<dynamic>> _pages = [];

  // Stateful Shell Route State
  AppStatefulShellRoute? _currentShell;
  int _currentBranchIndex = 0;
  final Map<int, List<Page<dynamic>>> _branchPages = {};

  AppRouterDelegate({
    required GlobalKey<NavigatorState> navigatorKey,
    required List<AppRouteBase> routes,
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
  AppRouteState get currentConfiguration {
    if (_pages.isNotEmpty) {
      return AppRouteState.fromPath(_pages.last.name ?? '/');
    } else if (_currentShell != null &&
        _branchPages.containsKey(_currentBranchIndex) &&
        _branchPages[_currentBranchIndex]!.isNotEmpty) {
      return AppRouteState.fromPath(
        _branchPages[_currentBranchIndex]!.last.name ?? '/',
      );
    }
    return AppRouteState.fromPath('/');
  }

  @override
  void dispose() {
    refreshListenable?.removeListener(notifyListeners);
    super.dispose();
  }

  // --- Auto Route / Flutter Nav 2.0 Style API ---

  /// Push a new route on top of the stack
  void push(String path, {Map<String, dynamic>? extra}) {
    logInfo('[Router] pushing new route: $path');
    _setPath(path, extra: extra, replace: false);
  }

  /// Replaces the current top route
  void replace(String path, {Map<String, dynamic>? extra}) {
    logInfo('[Router] replacing current route with: $path');
    _setPath(path, extra: extra, replace: true);
  }

  /// Clears the stack and pushes the targeted route (sama dengan go Router atau replaceAll auto_route).
  void replaceAll(String path, {Map<String, dynamic>? extra}) {
    logInfo('[Router] replaceAll stack with: $path');
    _pages.clear();
    _setPath(path, extra: extra, replace: false);
  }

  /// Pushes a new route and removes routes below it until the predicate returns true.
  void pushAndRemoveUntil(
    String path,
    bool Function(Page<dynamic> page) predicate, {
    Map<String, dynamic>? extra,
  }) {
    logInfo('[Router] pushAndRemoveUntil: $path');
    while (_pages.isNotEmpty && !predicate(_pages.last)) {
      _pages.removeLast();
    }
    _setPath(path, extra: extra, replace: false);
  }

  /// Returns true if the navigator can pop top most route.
  bool canPop() {
    if (_pages.isNotEmpty) return true;
    if (_currentShell != null &&
        _branchPages.containsKey(_currentBranchIndex)) {
      return _branchPages[_currentBranchIndex]!.length > 1;
    }
    return false;
  }

  /// Safely pops the topmost route.
  void pop() {
    logInfo('[Router] popping route');
    if (_pages.isNotEmpty) {
      _pages.removeLast();
      notifyListeners();
    } else if (_currentShell != null &&
        _branchPages.containsKey(_currentBranchIndex) &&
        _branchPages[_currentBranchIndex]!.length > 1) {
      _branchPages[_currentBranchIndex]!.removeLast();
      notifyListeners();
    } else {
      logInfo('[Router] cannot pop further');
    }
  }

  /// Pops the topmost route if possible, returning true if successful.
  bool maybePop() {
    logInfo('[Router] maybePop');
    if (canPop()) {
      pop();
      return true;
    }
    return false;
  }

  /// Pops routes consecutively until the predicate returns true.
  void popUntil(bool Function(Page<dynamic> page) predicate) {
    logInfo('[Router] popUntil');
    while (_pages.isNotEmpty && !predicate(_pages.last)) {
      _pages.removeLast();
    }
    notifyListeners();
  }

  /// Helper to pop until a specific route path is found.
  void popUntilPath(String path) {
    popUntil((page) => page.name != null && Uri.parse(page.name!).path == path);
  }

  DateTime? _lastBackPressTime;

  @override
  Future<bool> popRoute() async {
    logInfo('[Router] popRoute called (back button pressed)');
    if (maybePop()) {
      return true;
    }

    if (_currentShell != null && _currentBranchIndex != 0) {
      logInfo('[Router] redirecting to home branch instead of exiting');
      _switchBranch(0);
      return true;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      final context = navigatorKey.currentContext;
      if (context != null) {
        // AppToast info is from toast_utils, string is from localization extension
        AppToast.info(context.l10n.pressBackAgainToExit);
      }
      return true;
    }

    logInfo('[Router] exiting app');
    return false;
  }

  // --- Core Engine ---

  Future<void> _setPath(
    String path, {
    Map<String, dynamic>? extra,
    bool replace = false,
  }) async {
    final uri = Uri.parse(path);
    logInfo('[Router] setting location $path');

    final routeMatch = _matchRoute(uri.path);
    final routeState = AppRouteState.fromUri(uri, extra: extra);

    if (routeMatch != null) {
      logInfo('[Router] matched route ${routeMatch.path} for $path');

      if (routeMatch.redirect != null) {
        final redirectPath = await routeMatch.redirect!(routeState);
        if (redirectPath != null && redirectPath != path) {
          logInfo('[Router] redirecting to $redirectPath');
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

      bool isBranchRoute = false;
      if (_currentShell != null) {
        for (int i = 0; i < _currentShell!.branches.length; i++) {
          if (_findRouteInBranch(
                routeMatch.path,
                _currentShell!.branches[i].routes,
              ) !=
              null) {
            isBranchRoute = true;
            break;
          }
        }
      }

      if (isBranchRoute) {
        if (!_branchPages.containsKey(_currentBranchIndex)) {
          _branchPages[_currentBranchIndex] = [];
        }

        // Return from any active modals/global routes when jumping between branch routes natively
        _pages.clear();

        if (replace && _branchPages[_currentBranchIndex]!.isNotEmpty) {
          _branchPages[_currentBranchIndex]!.removeLast();
        }
        _branchPages[_currentBranchIndex]!.add(page);
      } else {
        if (replace && _pages.isNotEmpty) {
          _pages.removeLast();
        }
        _pages.add(page);
      }
    } else {
      final page = MaterialPage<dynamic>(
        key: const ValueKey('404'),
        name: '/404',
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(child: AppText(context.l10n.sharedRouteNotFound)),
          ),
        ),
      );
      if (replace && _pages.isNotEmpty) {
        _pages.removeLast();
      }
      _pages.add(page);
    }
    logInfo('[Router] Full paths for routes:');
    if (_currentShell != null) {
      logInfo('  => Shell branch [$_currentBranchIndex]');
      final currentBranchPages = _branchPages[_currentBranchIndex] ?? [];
      for (int i = 0; i < currentBranchPages.length; i++) {
        logInfo('  => ${currentBranchPages[i].name}');
      }
    }
    for (int i = 0; i < _pages.length; i++) {
      logInfo('  => ${_pages[i].name} (Global)');
    }
    notifyListeners();
  }

  AppRoute? _matchRoute(String path) {
    for (final route in _routes) {
      if (route is AppStatefulShellRoute) {
        for (int i = 0; i < route.branches.length; i++) {
          final branch = route.branches[i];
          final match = _findRouteInBranch(path, branch.routes);
          if (match != null) {
            _currentShell = route;
            _currentBranchIndex = i;
            return match;
          }
        }
      }
    }

    final matchRegular = _findRouteInBranch(path, _routes);
    if (matchRegular != null) {
      return matchRegular;
    }

    // fallback mapping to first path
    final fallback = _findRouteInBranch('/', _routes);
    if (fallback != null) {
      for (final r in _routes) {
        if (r is AppStatefulShellRoute) {
          for (int i = 0; i < r.branches.length; i++) {
            if (_findRouteInBranch('/', r.branches[i].routes) != null) {
              _currentShell = r;
              _currentBranchIndex = i;
              return fallback;
            }
          }
        }
      }
      _currentShell = null;
      return fallback;
    }
    return null;
  }

  AppRoute? _findRouteInBranch(String path, List<AppRouteBase> routes) {
    for (final route in routes) {
      if (route is AppRoute && route.path == path) {
        return route;
      }
      if (route.children.isNotEmpty) {
        final found = _findRouteInBranch(path, route.children);
        if (found != null) return found;
      }
    }
    return null;
  }

  void _switchBranch(int index) {
    if (index != _currentBranchIndex) {
      _currentBranchIndex = index;
      if (!_branchPages.containsKey(index) || _branchPages[index]!.isEmpty) {
        final initialRoute = _currentShell!.branches[index].routes.first;
        if (initialRoute is AppRoute) {
          _setPath(initialRoute.path, replace: true);
          return; // notifyListeners already called in setPath
        }
      }
      notifyListeners();
    } else {
      // Pop all to top for this branch if tapped again
      if (_branchPages.containsKey(index) && _branchPages[index]!.length > 1) {
        _branchPages[index]!.removeRange(1, _branchPages[index]!.length);
        notifyListeners();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Page<dynamic>>[];

    if (_currentShell != null) {
      final children = <Widget>[];
      for (int i = 0; i < _currentShell!.branches.length; i++) {
        final branchPages = _branchPages[i] ?? [];
        children.add(
          NavigatorPopHandler(
            enabled: i == _currentBranchIndex,
            onPopWithResult: (_) async {
              final handled = await popRoute();
              if (!handled) {
                await SystemNavigator.pop();
              }
            },
            child: Navigator(
              key:
                  _currentShell!.branches[i].navigatorKey ??
                  GlobalKey<NavigatorState>(debugLabel: 'Branch_$i'),
              pages: branchPages.isEmpty
                  ? [const MaterialPage<dynamic>(child: SizedBox.shrink())]
                  : List.of(branchPages),
              onDidRemovePage: (page) {
                if (branchPages.length > 1) {
                  branchPages.remove(page);
                  notifyListeners();
                }
              },
            ),
          ),
        );
      }

      final navigationShell = StatefulNavigationShell(
        currentIndex: _currentBranchIndex,
        onSwitchBranch: _switchBranch,
        children: children,
      );

      pages.add(
        MaterialPage<dynamic>(
          key: const ValueKey('AppShell'),
          name: 'shell',
          child: _currentShell!.builder(
            context,
            AppRouteState.fromPath('/'),
            navigationShell,
          ),
        ),
      );
    }

    pages.addAll(_pages);

    if (pages.isEmpty) {
      pages.add(
        MaterialPage<dynamic>(
          key: const ValueKey('404'),
          name: '/404',
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(child: AppText(context.l10n.sharedRouteNotFound)),
            ),
          ),
        ),
      );
    }

    return Navigator(
      key: navigatorKey,
      pages: pages,
      onDidRemovePage: (page) {
        if (_pages.contains(page)) {
          _pages.remove(page);
          notifyListeners();
        }
      },
    );
  }

  @override
  Future<void> setNewRoutePath(AppRouteState configuration) async {
    final uri = Uri.parse(configuration.path);
    if (_pages.isNotEmpty && _pages.last.name == uri.toString()) {
      return;
    }
    logInfo('[Router] setNewRoutePath ${configuration.path}');
    await _setPath(configuration.path, extra: configuration.extra);
  }
}
