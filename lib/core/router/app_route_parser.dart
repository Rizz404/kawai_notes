import 'package:flutter/widgets.dart';
import 'package:flutter_setup_riverpod/core/router/app_route_state.dart';

class AppRouteParser extends RouteInformationParser<AppRouteState> {
  const AppRouteParser();

  @override
  Future<AppRouteState> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final location = routeInformation.uri.path;
    if (location.isEmpty) {
      return AppRouteState.fromPath('/');
    }
    return AppRouteState.fromUri(routeInformation.uri);
  }

  @override
  RouteInformation restoreRouteInformation(AppRouteState configuration) {
    return RouteInformation(uri: configuration.uri);
  }
}
