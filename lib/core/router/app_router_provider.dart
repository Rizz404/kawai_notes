import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/router/app_route.dart';
import 'package:flutter_setup_riverpod/core/router/app_route_parser.dart';
import 'package:flutter_setup_riverpod/core/router/app_router_delegate.dart';
import 'package:flutter_setup_riverpod/core/router/router_observer.dart';
import 'package:flutter_setup_riverpod/core/router/router_refresh_listenable.dart';
import 'package:flutter_setup_riverpod/core/router/app_transitions.dart';
import 'package:flutter_setup_riverpod/feature/home/screens/home_screen.dart';

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
      path: '/second-page',
      name: 'second_page',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Second Page')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('This is the second screen'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(), // Menggunakan extension pop
                child: const Text('Pop Back'),
              ),
            ],
          ),
        ),
      ),
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
